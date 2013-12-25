//
//  Cryptography.m
//  TextSecureiOS
//
//  Created by Christine Corbett Moran on 3/26/13.
//  Copyright (c) 2013 Open Whisper Systems. All rights reserved.
//

#import "Cryptography.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonHMAC.h>
#include <CommonCrypto/CommonHMAC.h>

#import "NSData+Conversion.h"
#import "KeychainWrapper.h"
#import "Constants.h"
#import <RNCryptor/RNEncryptor.h>
#import <RNCryptor/RNDecryptor.h>

#include "NSString+Conversion.h"
#include "NSData+Base64.h"
#import "FilePath.h"
#import "TSEncryptedDatabaseError.h"


@implementation Cryptography


#pragma mark random bytes methods
+(NSMutableData*) generateRandomBytes:(int)numberBytes {
  /* used to generate db master key, and to generate signaling key, both at install */
  NSMutableData* randomBytes = [NSMutableData dataWithLength:numberBytes];
  int err = 0;
  err = SecRandomCopyBytes(kSecRandomDefault,numberBytes,[randomBytes mutableBytes]);
  if(err != noErr) {
    @throw [NSException exceptionWithName:@"random problem" reason:@"problem generating the random " userInfo:nil];
  }
  return randomBytes;
}




#pragma mark SHA1
+(NSString*)truncatedSHA1Base64EncodedWithoutPadding:(NSString*)string{
  /* used by TSContactManager to send hashed/truncated contact list to server */
  NSMutableData *hashData = [NSMutableData dataWithLength:20];
  CC_SHA1([[string dataUsingEncoding:NSUTF8StringEncoding] bytes], [[string dataUsingEncoding:NSUTF8StringEncoding] length], [hashData mutableBytes]);
  NSData *truncatedData = [hashData subdataWithRange:NSMakeRange(0, 10)];
  
  return [[truncatedData base64EncodedString] stringByReplacingOccurrencesOfString:@"=" withString:@""];
}

#pragma HMAC/SHA256

+(NSData*) truncatedHMAC:(NSData*)dataToHMAC withHMACKey:(NSData*)HMACKey {
  uint8_t ourHmac[CC_SHA256_DIGEST_LENGTH] = {0};
  CCHmac(kCCHmacAlgSHA256,
         [HMACKey bytes],
         [HMACKey length],
         [dataToHMAC bytes],
         [dataToHMAC  length],
         ourHmac);
  return [NSData dataWithBytes: ourHmac length: 10];
}



#pragma mark encrypted database key methods
+(NSData*) getEncryptedDatabaseKey:(NSData*)decryptedDatabaseKey withPassword:(NSString*)userPassword error:(NSError**) error  {
  
  return [RNEncryptor encryptData:decryptedDatabaseKey withSettings:kRNCryptorAES256Settings password:userPassword error:nil];
}

+(NSData*) getDecryptedDatabaseKey:(NSString*)encryptedDatabaseKey withPassword:(NSString*)userPassword error:(NSError**) error  {
  
  NSData* decryptedDatabaseKey= [RNDecryptor decryptData:[NSData dataFromBase64String:encryptedDatabaseKey] withPassword:userPassword error:error];
  if ((!decryptedDatabaseKey) && (error) && ([*error domain] == kRNCryptorErrorDomain) && ([*error code] == kRNCryptorHMACMismatch)) {
    *error = [TSEncryptedDatabaseError invalidPassword];
    return nil;
  }
  else {
    return decryptedDatabaseKey;
  }
}



#pragma mark push payload encryptiong/decryption
+(NSData*) decryptPushPayload:(NSData*) dataToDecrypt withKey:(NSData*) key withIV:(NSData*) iv withVersion:(NSData*)version withHMACKey:(NSData*) hmacKey forHMAC:(NSData *)hmac{
  /* AES256 CBC encrypt then mac 
   Returns nil if hmac invalid or decryption fails
   */
  //verify hmac of version||encrypted data||iv
  NSMutableData *dataToHmac = [NSMutableData data ];
  [dataToHmac appendData:version];
  [dataToHmac appendData:iv];
  [dataToHmac appendData:dataToDecrypt];
  
  // verify hmac
  NSData* ourHmacData = [Cryptography truncatedHMAC:dataToHmac withHMACKey:hmacKey];
  if(![ourHmacData isEqualToData:hmac]) {
    return nil;
  }
  
  // decrypt
  size_t bufferSize           = [dataToDecrypt length] + kCCBlockSizeAES128;
  void* buffer                = malloc(bufferSize);
  
  size_t bytesDecrypted    = 0;
  CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                        [key bytes], [key length],
                                        [iv bytes],
                                        [dataToDecrypt bytes], [dataToDecrypt length],
                                        buffer, bufferSize,
                                        &bytesDecrypted);
  if (cryptStatus == kCCSuccess) {
    return [NSData dataWithBytesNoCopy:buffer length:bytesDecrypted];
  }
  
  free(buffer);
  return nil;
  
  
}


+(NSData*)encryptPushPayload:(NSData*) dataToEncrypt withKey:(NSData*) key withIV:(NSData*) iv withVersion:(NSData*)version  withHMACKey:(NSData*) hmacKey computedHMAC:(NSData**)hmac {
  /* AES256 CBC encrypt then mac
   Returns nil if encryption fails
   */
  size_t bufferSize           = [dataToEncrypt length] + kCCBlockSizeAES128;
  void* buffer                = malloc(bufferSize);
  
  size_t bytesEncrypted    = 0;
  CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                        [key bytes], [key length],
                                        [iv bytes],
                                        [dataToEncrypt bytes], [dataToEncrypt length],
                                        buffer, bufferSize,
                                        &bytesEncrypted);
  
  if (cryptStatus == kCCSuccess){
    NSData* encryptedData= [NSData dataWithBytesNoCopy:buffer length:bytesEncrypted];
    //compute hmac of version||encrypted data||iv
    NSMutableData *dataToHmac = [NSMutableData data];
    [dataToHmac appendData:version];
    [dataToHmac appendData:iv];
    [dataToHmac appendData:encryptedData];
    *hmac = [Cryptography truncatedHMAC:dataToHmac withHMACKey:hmacKey];
    return encryptedData;
  }
  free(buffer);
  return nil;
  
}





@end

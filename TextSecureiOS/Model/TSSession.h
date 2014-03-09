//
//  TSSession.h
//  TextSecureiOS
//
//  Created by Frederic Jacobs on 01/03/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TSContact.h"
#import "RKCK.h"
#import "TSWhisperMessageKeys.h"
#import "TSPrekey.h"
#import "TSChainKey.h"
#import "TSEncryptedWhisperMessage.hh"

@interface TSSession : NSObject

@property(readonly)int deviceId;
@property(readonly)TSContact *contact;

@property(copy)NSData *theirEphemeralKey;
@property(readwrite)NSData *rootKey;

@property NSData *ephemeralReceiving;
@property TSECKeyPair *ephemeralOutgoing;
@property int PN;

- (TSSession*)initWithContact:(TSContact*)contact deviceId:(int)deviceId;
- (NSData*)theirIdentityKey;

- (BOOL)hasReceiverChain:(NSData*) ephemeral;
- (BOOL)hasSenderChain;

- (TSChainKey*)receiverChainKey:(NSData*)senderEphemeral;
- (TSChainKey*)senderChainKey;

- (TSChainKey*)addReceiverChain:(NSData*)senderEphemeral chainKey:(TSChainKey*)chainKey;
- (TSChainKey*)setSenderChain:(TSECKeyPair*)senderEphemeralPair chainkey:(TSChainKey*)chainKey;

@end

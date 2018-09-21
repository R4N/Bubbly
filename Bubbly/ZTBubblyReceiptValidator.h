//
//  ZSBubblyReceiptValidator.h
//  Bubbly
//
//  Created by Micah T. Moore on 8/1/18.
//  Copyright © 2018 Zetetic LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZTLicenseState.h"

// Domain for any errors we plan to provide
FOUNDATION_EXTERN NSString * _Nonnull const ZTLicenseManagerErrorDomain;

// Constant keys for accessing Receipt dictionary data
FOUNDATION_EXTERN NSString * _Nonnull const kReceiptBundleID;
FOUNDATION_EXTERN NSString * _Nonnull const kReceiptBundleIDData;
FOUNDATION_EXTERN NSString * _Nonnull const kReceiptVersion;
FOUNDATION_EXTERN NSString * _Nonnull const kReceiptOpaqueValue;
FOUNDATION_EXTERN NSString * _Nonnull const kReceiptHashValue;
FOUNDATION_EXTERN NSString * _Nonnull const kReceiptOriginalVersion;
FOUNDATION_EXTERN NSString * _Nonnull const kReceiptInAppPurchases;
FOUNDATION_EXTERN NSString * _Nonnull const kReceiptInAppProductID;
FOUNDATION_EXTERN NSString * _Nonnull const kReceiptInAppQuantity;
FOUNDATION_EXTERN NSString * _Nonnull const kReceiptInAppTransactionID;
FOUNDATION_EXTERN NSString * _Nonnull const kReceiptInAppPurchaseDate;
FOUNDATION_EXTERN NSString * _Nonnull const kReceiptInAppOriginalTransactionID;
FOUNDATION_EXTERN NSString * _Nonnull const kReceiptInAppOriginalPurchaseDate;

typedef NS_ENUM(NSUInteger, ZTReceiptError) {
    ZTReceiptErrorReceiptUnavailable = 1,
    ZTReceiptErrorReceiptInvalid,
};

NS_ASSUME_NONNULL_BEGIN

@protocol ZTBubblyReceiptValidatorDelegate<NSObject>
@required
- (void)receiptValidatorDidReceiveReceiptError:(NSError * _Nonnull)error;
- (void)receiptValidatorDidUpdateLicenseState:(ZTLicenseState)state;
@end

@interface ZTBubblyReceiptValidator : NSObject
@property (readonly) NSInteger requiredLicenseVersion;
@property ZTLicenseState state;
@property id <ZTBubblyReceiptValidatorDelegate> delegate;
+ (instancetype _Nonnull)sharedValidator;
- (void)checkReceiptAtURL:(NSURL * _Nonnull)receiptURL;
@end

NS_ASSUME_NONNULL_END

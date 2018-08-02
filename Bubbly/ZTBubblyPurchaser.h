//
//  ZSBubblyPurchaser.h
//  Bubbly
//
//  Created by Micah T. Moore on 8/1/18.
//  Copyright © 2018 Zetetic LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ZTBubblyPurchaserDelegate <NSObject>
- (void)didLoadProducts:(NSArray <SKProduct *> *)products;
@end

@interface ZTBubblyPurchaser : NSObject
@property id <ZTBubblyPurchaserDelegate> delegate;
- (void)requestProducts;
@end

NS_ASSUME_NONNULL_END

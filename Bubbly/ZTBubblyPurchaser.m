//
//  ZSBubblyPurchaser.m
//  Bubbly
//
//  Created by Micah T. Moore on 8/1/18.
//  Copyright © 2018 Zetetic LLC. All rights reserved.
//

#import "ZTBubblyPurchaser.h"

#define IAP_TRIAL_PRODUCT_ID @"net.zetetic.Bubbles.trial2"
#define IAP_UNLIMITED_PRODUCT_ID @"net.zetetic.Bubbles.unlimited2"

@interface ZTBubblyPurchaser() <SKProductsRequestDelegate>
@property (strong, nullable) NSArray <NSString *> *productIDs;
@end

@implementation ZTBubblyPurchaser

- (instancetype)init {
    self = [super init];
    if (self) {
        _productIDs = @[IAP_TRIAL_PRODUCT_ID, IAP_UNLIMITED_PRODUCT_ID];
    }
    return self;
}

- (void)requestProducts {
    if ([SKPaymentQueue canMakePayments]) {
        // which set you repping?
        NSSet *productSet = [NSSet setWithArray:self.productIDs];
        SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:productSet];
        request.delegate = self;
        [request start];
    } else {
        // just log it out for this POC
        NSLog(@"We can't make payments!");
    }
}

- (void)productsRequest:(nonnull SKProductsRequest *)request didReceiveResponse:(nonnull SKProductsResponse *)response {
    if (response.products.count > 0) {
        NSLog(@"We have a product in the response!");
        if (self.delegate && [self.delegate respondsToSelector:@selector(didLoadProducts:)]) {
            [self.delegate didLoadProducts:response.products];
        }
    } else if (response.invalidProductIdentifiers.count > 0) {
        NSLog(@"We have invalid product ids = %@", response.invalidProductIdentifiers);
    } else {
        NSLog(@"There are absolutely no products returned!");
    }
}

@end

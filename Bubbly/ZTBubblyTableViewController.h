//
//  ZSBubblyTableViewController.h
//  Bubbly
//
//  Created by Micah T. Moore on 8/1/18.
//  Copyright © 2018 Zetetic LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZTBubblyPurchaser.h"

NS_ASSUME_NONNULL_BEGIN

@protocol ZTBubblyTableViewControllerDelegate <NSObject>
- (void)didPurchaseProduct;
@end

@interface ZTBubblyTableViewController : UITableViewController <UITableViewDelegate, UITableViewDataSource>
@property id <ZTBubblyTableViewControllerDelegate> delegate;
@end

NS_ASSUME_NONNULL_END

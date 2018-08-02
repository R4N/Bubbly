//
//  ZSBubblyTableViewController.m
//  Bubbly
//
//  Created by Micah T. Moore on 8/1/18.
//  Copyright © 2018 Zetetic LLC. All rights reserved.
//

#import "ZTBubblyTableViewController.h"
#import "ZTBlockerViewController.h"

@interface ZTBubblyTableViewController () <ZTBubblyPurchaserDelegate, SKPaymentTransactionObserver>
@property (strong, nullable) ZTBubblyPurchaser *purchaser;
@property (strong, nullable) NSArray <SKProduct *> *productsArray;
@property NSInteger selectedIndex;
@property BOOL transactionInProgress;
@property (strong, nullable) ZTBlockerViewController *blockerView;
- (void)_showBuyOptions;
@end

@implementation ZTBubblyTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Bubbly Purchase";
    self.purchaser = [[ZTBubblyPurchaser alloc] init];
    self.purchaser.delegate = self;
    self.blockerView = [[ZTBlockerViewController alloc] init];
    [self presentViewController:self.blockerView animated:NO completion:^{
        [self.purchaser requestProducts];
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }];
}

- (void)didLoadProducts:(NSArray<SKProduct *> *)products {
    self.productsArray = products;
    [self.blockerView dismissViewControllerAnimated:NO completion:^{
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self.tableView reloadData];
        }];
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.productsArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ZSBubblyProductCell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ZSBubblyProductCell"];
    }
    SKProduct *product = [self.productsArray objectAtIndex:indexPath.row];
    cell.textLabel.text = product.localizedTitle;
    cell.detailTextLabel.text = product.localizedDescription;
    return cell;
}

#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60.0f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.selectedIndex = indexPath.row;
    [self _showBuyOptions];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Show buy options

- (void)_showBuyOptions {
    if (self.transactionInProgress) {
        return;
    }
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Bubbles Purchase" message:@"What would you like to do?" preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *buyAction = [UIAlertAction actionWithTitle:@"Buy" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        SKPayment *payment = [SKPayment paymentWithProduct:[self.productsArray objectAtIndex:self.selectedIndex]];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
        self.transactionInProgress = YES;
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
    [ac addAction:buyAction];
    [ac addAction:cancelAction];
    [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased: {
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                self.transactionInProgress = NO;
                if (self.delegate && [self.delegate respondsToSelector:@selector(didPurchaseProduct)]) {
                    [self.delegate didPurchaseProduct];
                }
                [self.navigationController popViewControllerAnimated:YES];
                break;
            }
            case SKPaymentTransactionStateFailed: {
                // just log it out for this POC
                NSLog(@"The transaction failed!");
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                self.transactionInProgress = NO;
                break;
            }
            default:
                break;
        }
    }
}

- (void)dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

@end

//
//  ViewController.m
//  Bubbles
//
//  Created by Micah T. Moore on 7/31/18.
//  Copyright © 2018 Zetetic LLC. All rights reserved.
//

#import "ViewController.h"
#import "ZTBubblyTableViewController.h"
#import "ZTBubblyReceiptValidator.h"
#import <StoreKit/SKReceiptRefreshRequest.h>

@interface ViewController () <SKRequestDelegate, ZTBubblyTableViewControllerDelegate, ZTBubblyReceiptValidatorDelegate>
@property (strong) IBOutlet UIImageView *imageView;
@property (strong) IBOutlet UILabel *trialLabel;
- (void)_addShadowToImageView;
- (IBAction)validateReceipt:(id)sender;
- (IBAction)viewProducts:(id)sender;
- (BOOL)_lookForLocalReceipt;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self _addShadowToImageView];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)_addShadowToImageView {
    UIColor *blackColor = [UIColor blackColor];
    self.imageView.layer.shadowColor = blackColor.CGColor;
    self.imageView.layer.shadowOffset = CGSizeMake(0, 1);
    self.imageView.layer.shadowOpacity = 1;
    self.imageView.layer.shadowRadius = 4.0;
    self.imageView.clipsToBounds = NO;
}

- (IBAction)validateReceipt:(id)sender {
    if ([self _lookForLocalReceipt] == NO) {
        // no local receipt found, go out and try to find one
        SKReceiptRefreshRequest *request = [[SKReceiptRefreshRequest alloc] init];
        [request setDelegate:self];
        [request start];
    } else {
        // we have the receipt locally let's use it!
        ZTBubblyReceiptValidator *validator = [ZTBubblyReceiptValidator sharedValidator];
        validator.delegate = self;
        [validator checkReceiptAtURL:[[NSBundle mainBundle] appStoreReceiptURL]];
    }
}

- (BOOL)_lookForLocalReceipt {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSURL *receiptURL = [mainBundle appStoreReceiptURL];
    NSError *receiptError;
    BOOL isPresent = [receiptURL checkResourceIsReachableAndReturnError:&receiptError];
    return isPresent;
}

- (IBAction)viewProducts:(id)sender {
    ZTBubblyTableViewController *tableVC = [[ZTBubblyTableViewController alloc] init];
    tableVC.delegate = self;
    [self.navigationController pushViewController:tableVC animated:YES];
}

#pragma mark ZSBubblyTableViewControllerDelegate

- (void)didPurchaseProduct {
    // product got purchased, let's re-examine the receipt
    ZTBubblyReceiptValidator *validator = [ZTBubblyReceiptValidator sharedValidator];
    validator.delegate = self;
    [validator checkReceiptAtURL:[[NSBundle mainBundle] appStoreReceiptURL]];
}

#pragma mark SKRequestDelegate

- (void)requestDidFinish:(SKRequest *)request {
    if ([self _lookForLocalReceipt]) {
        ZTBubblyReceiptValidator *validator = [ZTBubblyReceiptValidator sharedValidator];
        validator.delegate = self;
        [validator checkReceiptAtURL:[[NSBundle mainBundle] appStoreReceiptURL]];
    }
    // fail silently if we didn't get a receipt here
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    // just log this error for this POC
    NSLog(@"Request did fail with error = %@", error);
}

#pragma mark - ZTBubblyReceiptValidatorDelegate

- (void)receiptValidatorDidReceiveReceiptError:(NSError * _Nonnull)error {
    // just log the error for this POC
    NSLog(@"We received a receipt error over here = %@", error);
}

- (void)receiptValidatorDidUpdateLicenseState:(ZTLicenseState)state {
    switch (state) {
        case ZTLicenseStateNone: {
            self.trialLabel.text = @"Julian (Unknown)";
            self.imageView.image = [UIImage imageNamed:@"Julian-TPB"];
            break;
        }
        case ZTLicenseStateTrial: {
            self.trialLabel.text = @"Ricky (Trial)";
            self.imageView.image = [UIImage imageNamed:@"Ricky-TPB"];
            break;
        }
        case ZTLicenseStateTrialExpired: {
            self.trialLabel.text = @"Randy (Trial Expired)";
            self.imageView.image = [UIImage imageNamed:@"Randy-TPB"];
            break;
        }
        case ZTLicenseStateValidated: {
            self.trialLabel.text = @"Bubbles (Unlocked)";
            self.imageView.image = [UIImage imageNamed:@"Bubbles-TPB"];
            break;
        }
        default:
            break;
    }
}

@end

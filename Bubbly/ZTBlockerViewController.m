//
//  ZTBlockerViewController.m
//  Bubbly
//
//  Created by Micah T. Moore on 8/1/18.
//  Copyright © 2018 Zetetic LLC. All rights reserved.
//

#import "ZTBlockerViewController.h"

@interface ZTBlockerViewController ()
@property (strong, nullable) IBOutlet UIActivityIndicatorView *spinner;
@end

@implementation ZTBlockerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.spinner startAnimating];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.spinner stopAnimating];
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end

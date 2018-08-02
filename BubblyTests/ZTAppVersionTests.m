//
//  ZTAppVersionTest.m
//  Bubbles
//
//  Created by Billy Gray on 1/18/18.
//

#import <XCTest/XCTest.h>
#import "ZTAppVersion.h"

@interface ZTAppVersionTest : XCTestCase
- (BOOL)checkVersion:(ZTAppVersion *)version against:(NSArray <NSNumber *> *)components;
@end

@implementation ZTAppVersionTest

- (BOOL)checkVersion:(ZTAppVersion *)version against:(NSArray <NSNumber *> *)components {
    return [version.components isEqualToArray:components];
}

- (void)testBasicVersions {
    ZTAppVersion *a = [ZTAppVersion versionWithString:@"3.3.3"];
    NSArray<NSNumber *> *aC = @[@(3), @(3), @(3)];
    XCTAssertTrue([self checkVersion:a against:aC]);
    ZTAppVersion *b = [ZTAppVersion versionWithString:@"3.3.4"];
    NSArray<NSNumber *> *bC = @[@(3), @(3), @(4)];
    XCTAssertTrue([self checkVersion:b against:bC]);
    ZTAppVersion *c = [ZTAppVersion versionWithString:@"3.5.1"];
    NSArray<NSNumber *> *cC = @[@(3), @(5), @(1)];
    XCTAssertTrue([self checkVersion:c against:cC]);
    ZTAppVersion *d = [ZTAppVersion versionWithString:@"1.6.4"];
    NSArray<NSNumber *> *dC = @[@(1), @(6), @(4)];
    XCTAssertTrue([self checkVersion:d against:dC]);
    for (ZTAppVersion *v in @[a, b, c, d]) {
        XCTAssertNotNil(v, @"Valid version strings should not return nil");
    }
}

- (void)testComparisons {
    ZTAppVersion *a = [ZTAppVersion versionWithString:@"3.3.3"];
    ZTAppVersion *b = [ZTAppVersion versionWithString:@"3.3.4"];
    ZTAppVersion *c = [ZTAppVersion versionWithString:@"3.5.1"];
    ZTAppVersion *d = [ZTAppVersion versionWithString:@"1.6.4"];
    ZTAppVersion *e = [ZTAppVersion versionWithString:@"3.3.3"];
    XCTAssertTrue([a isLessThan:b]);
    XCTAssertTrue([a isLessThan:c]);
    XCTAssertTrue([c isLessThan:a] == NO);
    XCTAssertTrue([d isLessThan:a]);
    XCTAssertEqual([a compare:e], NSOrderedSame);
}

- (void)testWorstCasePerformance {
    ZTAppVersion *a = [ZTAppVersion versionWithString:@"3.3.3"];
    ZTAppVersion *b = [ZTAppVersion versionWithString:@"3.3.3"];
    [self measureBlock:^{
        [a compare:b];
    }];
}

- (void)testBestCasePerformance {
    ZTAppVersion *a = [ZTAppVersion versionWithString:@"3.3.3"];
    ZTAppVersion *b = [ZTAppVersion versionWithString:@"1.6.4"];
    [self measureBlock:^{
        [a compare:b];
    }];
}

@end

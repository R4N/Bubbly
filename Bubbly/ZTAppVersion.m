//
//  ZTAppVersion.m
//  Bubbly
//
//  Created by Micah T. Moore on 8/1/18.
//  Copyright © 2018 Zetetic LLC. All rights reserved.
//

#import "ZTAppVersion.h"

#define SUPPORTED_NUMBER_OF_COMPONENTS 3

@interface ZTAppVersion ()
@end

@implementation ZTAppVersion

@synthesize components = _components;
@dynamic majorVersion;
@dynamic minorVersion;
@dynamic pointVersion;

- (nullable instancetype)initWithString:(NSString * _Nonnull)string {
    self = [super init];
    if (self != nil) {
        // Split the version string up into three components
        NSArray<NSString *> *components = [string componentsSeparatedByString:@"."];
        NSMutableArray<NSNumber *> *numbers = [NSMutableArray arrayWithCapacity:SUPPORTED_NUMBER_OF_COMPONENTS];
        for (NSString *version in components) {
            NSNumber *num = [NSNumber numberWithUnsignedInteger:[version integerValue]];
            [numbers addObject:num];
        }
        while (numbers.count < SUPPORTED_NUMBER_OF_COMPONENTS) {
            // add 0's for all version portions missing
            // i.e. if our version is 1.0, we'll want it to actually be in the form of 1.0.0
            [numbers addObject:@(0)];
        }
        _components = numbers;
    }
    return self;
}

+ (nullable instancetype)versionWithString:(NSString * _Nonnull)string {
    return [[[self class] alloc] initWithString:string];
}

- (NSUInteger)majorVersion {
    return [self.components[0] unsignedIntegerValue];
}

- (NSUInteger)minorVersion {
    return [self.components[1] unsignedIntegerValue];
}

- (NSUInteger)pointVersion {
    return [self.components[2] unsignedIntegerValue];
}

- (NSUInteger)supportedComponentsLength {
    return (NSUInteger)SUPPORTED_NUMBER_OF_COMPONENTS;
}

- (NSComparisonResult)compare:(ZTAppVersion *)otherObject {
    NSComparisonResult res = NSOrderedSame;
    NSUInteger i = 0;
    while (i < SUPPORTED_NUMBER_OF_COMPONENTS) {
        if ([self.components[i] unsignedIntegerValue] != [otherObject.components[i] unsignedIntegerValue]) {
            if ([self.components[i] unsignedIntegerValue] < [otherObject.components[i] unsignedIntegerValue]) {
                res = NSOrderedAscending; // "The left operand is smaller than the right operand"
                break;
            } else {
                res = NSOrderedDescending; // "The left operand is greater than the right operand."
                break;
            }
        }
        i++;
    }
    return res;
}

- (BOOL)isLessThan:(ZTAppVersion * _Nonnull)otherVersion {
    return ([self compare:otherVersion] == NSOrderedAscending);
}

@end

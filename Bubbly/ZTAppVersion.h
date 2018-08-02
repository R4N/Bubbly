//
//  ZTAppVersion.h
//  Bubbly
//
//  Created by Micah T. Moore on 8/1/18.
//  Copyright © 2018 Zetetic LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZTAppVersion : NSObject

@property (readonly, strong, nonnull) NSArray<NSNumber *> *components;
@property (readonly) NSUInteger majorVersion;
@property (readonly) NSUInteger minorVersion;
@property (readonly) NSUInteger pointVersion;
@property (readonly) NSUInteger supportedComponentsLength;

/**
 @brief Unavailable. Please use `initWithIdentifiers:`
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

- (nullable instancetype)initWithString:(NSString * _Nonnull)string NS_DESIGNATED_INITIALIZER;
+ (nullable instancetype)versionWithString:(NSString * _Nonnull)string;
- (NSComparisonResult)compare:(ZTAppVersion * _Nonnull)otherObject;
- (BOOL)isLessThan:(ZTAppVersion * _Nonnull)otherVersion;

@end

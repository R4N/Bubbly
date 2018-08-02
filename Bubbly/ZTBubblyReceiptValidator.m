//
//  ZSBubblyReceiptValidator.m
//  Bubbly
//
//  Created by Micah T. Moore on 8/1/18.
//  Copyright © 2018 Zetetic LLC. All rights reserved.
//

#import "ZTBubblyReceiptValidator.h"
#import "ZTAppVersion.h"
// TODO: possibly if def this if the validator wants to be re-used for macOS
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>

#include <openssl/pkcs7.h>
#include <openssl/objects.h>
#include <openssl/sha.h>
#include <openssl/x509.h>
#include <openssl/err.h>
#include <openssl/asn1.h>
#include <openssl/bio.h>
#include <openssl/evp.h>

#define BUNDLE_ID 2
#define VERSION 3
#define OPAQUE_VALUE 4
#define HASH 5
#define INAPP_PURCHASE 17
#define ORIGINAL_VERSION 19
#define INAPP_QTY 1701
#define INAPP_PRODUCT_ID 1702
#define INAPP_TRANSACTION_ID 1703
#define INAPP_PURCHASE_DATE 1704
#define INAPP_ORIGINAL_TRANSACTION_ID 1705
#define INAPP_ORIGINAL_PURCHASE_DATE 1706

static NSString * kBubblyBundleID = @"net.zetetic.Bubbly";
static NSString * kBubblyCurrentVersion = @"1";
// the version prior to starting free trials
// should be treated the same as full unlimited purchase
static NSString * kLicenseRequiredVersion = @"1.0.0";
static NSString * kBubblyUnlimitedProductIdentifier = @"net.zetetic.Bubbles.unlimited2";
static NSString * kBubblyTrialProductIdentifier = @"net.zetetic.Bubbles.trial2";

NSString * const ZSBubblyReceiptValidatorErrorDomain = @"ZSBubblyReceiptValidatorErrorDomain";
NSString * const kReceiptBundleID = @"kReceiptBundleID";
NSString * const kReceiptBundleIDData = @"kReceiptBundleIDData";
NSString * const kReceiptVersion = @"kReceiptVersion";
NSString * const kReceiptOpaqueValue = @"kReceiptOpaqueValue";
NSString * const kReceiptHashValue = @"kReceiptHashValue";
NSString * const kReceiptOriginalVersion = @"kReceiptOriginalVersion";
NSString * const kReceiptInAppPurchases = @"kReceiptInAppPurchases";
NSString * const kReceiptInAppProductID = @"kReceiptInAppProductID";
NSString * const kReceiptInAppTransactionID = @"kReceiptInAppTransactionID";
NSString * const kReceiptInAppPurchaseDate = @"kReceiptInAppPurchaseDate";
NSString * const kReceiptInAppOriginalTransactionID = @"kReceiptInAppOriginalTransactionID";
NSString * const kReceiptInAppOriginalPurchaseDate = @"kReceiptInAppOriginalPurchaseDate";
NSString * const kReceiptInAppQuantity = @"kReceiptInAppQuantity";

@interface ZTBubblyReceiptValidator()
- (NSError *_Nonnull)_errorWithCode:(ZTReceiptError)code title:(NSString *_Nullable)title message:(NSString *_Nullable)message;
- (NSDictionary * _Nullable)_parseAndValidateReceiptAtURL:(NSURL * _Nonnull)receiptURL error:(NSError * _Nullable * _Nullable)error;
- (BOOL)_doesHashMatchFromReceipt:(NSDictionary *)receipt;
- (BOOL)_doesBundleIDMatchFromReceipt:(NSDictionary *)receipt;
- (BOOL)_doesVersionMatchFromReceipt:(NSDictionary *)receipt;
@end

@implementation ZTBubblyReceiptValidator


- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _state = ZTLicenseStateNone;
        _requiredLicenseVersion = [[ZTAppVersion alloc] initWithString:kLicenseRequiredVersion];
    }
    return self;
}

static ZTBubblyReceiptValidator  *__sharedValidator = nil;

+ (instancetype _Nonnull)sharedValidator {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (__sharedValidator == nil) {
            __sharedValidator = [[self alloc] init];
        }
    });
    return __sharedValidator;
}



- (void)checkReceiptAtURL:(NSURL * _Nonnull)receiptURL {
    NSError *receiptError = nil;
    NSDictionary *receiptInfo = [self _parseAndValidateReceiptAtURL:receiptURL error:&receiptError];
    if (receiptError != nil) {
        // There's a problem with the receipt! We don't have enough info to do anything, so bail and let the delegate know
        if (self.delegate != nil && [self.delegate respondsToSelector:@selector(receiptValidatorDidReceiveReceiptError:)]) {
            [self.delegate receiptValidatorDidReceiveReceiptError:receiptError];
        }
        return;
    }
    // Okay first thing we need to know is if this user requires a license at all
    NSString *originalVersionString = [receiptInfo objectForKey:kReceiptOriginalVersion];
    ZTAppVersion *originalVersion = [ZTAppVersion versionWithString:originalVersionString];
    if ([originalVersion isLessThan:self.requiredLicenseVersion] == NO) {
        // License required, check for standard in-app purchase
        NSArray *purchases = [receiptInfo objectForKey:kReceiptInAppPurchases];
        for (NSDictionary *item in purchases) {
            NSString *productID = [item objectForKey:kReceiptInAppProductID];
            if ([productID isEqualToString:kBubblyUnlimitedProductIdentifier]) {
                // License approved, user is approved for full access
                self.state = ZTLicenseStateValidated;
                break;
            } else if ([productID isEqualToString:kBubblyTrialProductIdentifier]) {
                // the user has purchase a trial, let's check the date of purchase
                NSString *trialStartString = [item objectForKey:kReceiptInAppOriginalPurchaseDate];
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
                [dateFormatter setLocale:enUSPOSIXLocale];
                [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
                NSDate *trialStartDate = [dateFormatter dateFromString:trialStartString];
                NSTimeInterval secondsPerDay = 24 * 60 * 60;
                // In production this should be checked against a date server because the user can change the device date
                if ([[NSDate date] timeIntervalSinceDate:[trialStartDate dateByAddingTimeInterval:secondsPerDay * 14]] > 0) {
                    // Sorry, Charlie
                    self.state = ZTLicenseStateTrialExpired;
                    // TODO: present store UI
                } else {
                    self.state = ZTLicenseStateTrial;
                }
            }
        }
    } else {
        // Nothing else to do, user paid full price for original version, approved for full access
        self.state = ZTLicenseStateValidated;
    }
    // Let the delegate know the new state so it can adapt the app's UI if necessary
    if (self.delegate && [self.delegate respondsToSelector:@selector(receiptValidatorDidUpdateLicenseState:)]) {
        [self.delegate receiptValidatorDidUpdateLicenseState:self.state];
    }
    if (self.state == ZTLicenseStateTrialExpired) {
        // just log it out for this POC
        NSLog(@"Our trial is expired!");
    }
}

#pragma mark - Receipt Parsing

- (NSDictionary * _Nullable)_parseAndValidateReceiptAtURL:(NSURL * _Nonnull)receiptURL
                                                    error:(NSError * _Nullable * _Nullable)error {
    OpenSSL_add_all_digests();
    NSError *receiptError;
    // this should have already been checked before calling, but we'll recheck again
    BOOL exists = [receiptURL checkResourceIsReachableAndReturnError:&receiptError];
    if (exists == NO) {
        if (error != NULL) {
            *error = [self _errorWithCode:ZTReceiptErrorReceiptUnavailable
                                    title:@"Receipt is Unavailable"
                                  message:[NSString stringWithFormat:@"Receipt could not be accessed at %@", receiptURL]];
        }
        return nil;
    }
    // Now let's load it up as a PKCS7 container and validate that it was signed by Apple by checking against our bundled cert for them
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    // Here we create a memory buffer to extract the contents
    BIO *receiptBIO = BIO_new(BIO_s_mem());
    // Copy into the buffer
    BIO_write(receiptBIO, [receiptData bytes], (int) [receiptData length]);
    // Create PKCS7 container struct from buffer
    PKCS7 *receiptPKCS7 = d2i_PKCS7_bio(receiptBIO, NULL);
    if (receiptPKCS7 == NULL) {
        if (error != NULL) {
            *error = [self _errorWithCode:ZTReceiptErrorReceiptInvalid
                                    title:@"Receipt is Invalid"
                                  message:@"Unable to decode PKCS7 container"];
        }
        PKCS7_free(receiptPKCS7);
        BIO_free(receiptBIO);
        return nil;
    }
    if (!PKCS7_type_is_signed(receiptPKCS7)) {
        if (error != NULL) {
            *error = [self _errorWithCode:ZTReceiptErrorReceiptInvalid
                                    title:@"Receipt is Invalid"
                                  message:@"PKCS7 container is not signed"];
        }
        PKCS7_free(receiptPKCS7);
        BIO_free(receiptBIO);
        return nil;
    }
    
    // Load up the Apple cert for verifying the container sig
    NSURL *appleRootURL = [[NSBundle mainBundle] URLForResource:@"AppleIncRootCertificate" withExtension:@"cer"];
    NSData *appleRootData = [NSData dataWithContentsOfURL:appleRootURL];
    BIO *appleRootBIO = BIO_new(BIO_s_mem());
    BIO_write(appleRootBIO, (const void *) [appleRootData bytes], (int) [appleRootData length]);
    X509 *appleRootX509 = d2i_X509_bio(appleRootBIO, NULL);
    X509_STORE *store = X509_STORE_new();
    X509_STORE_add_cert(store, appleRootX509);
    // Verify the signatures match
    BIO *payload = BIO_new(BIO_s_mem());
    int result = PKCS7_verify(receiptPKCS7, NULL, store, NULL, payload, 0);
    BIO_free(payload);
    // Release these guys
    X509_STORE_free(store);
    X509_free(appleRootX509);
    BIO_free(appleRootBIO);
    if (result != 1) {
        long pkcs_err = ERR_get_error();
        const char* error_string = ERR_error_string(pkcs_err, NULL);
        NSLog(@"PKCS7_verify returned error code %ld, error string %s", pkcs_err, error_string);
        if (error != NULL) {
            *error = [self _errorWithCode:ZTReceiptErrorReceiptInvalid
                                    title:@"Receipt is Invalid"
                                  message:@"PKCS7 container signature is invalid"];
        }
        PKCS7_free(receiptPKCS7);
        BIO_free(receiptBIO);
        return nil;
    }
    // Fantastic, now we decode the payload using ASN1 to get all the receipt attributes, in-app purchases, etc
    ASN1_OCTET_STRING *octetString = receiptPKCS7->d.sign->contents->d.data;
    // Set up the pile of variables we'll need to decode attributes and store them
    const unsigned char *pointer = octetString->data;
    const unsigned char *end = pointer + octetString->length;
    const unsigned char *str_ptr;
    int type = 0;
    int xclass = 0;
    long length = 0;
    // These guys are for reading the additional string attributes values
    int str_type = 0;
    int str_xclass = 0;
    long str_length = 0;
    NSMutableDictionary *receiptDict = [NSMutableDictionary dictionary];
    // Decode the payload
    ASN1_get_object(&pointer, &length, &type, &xclass, end - pointer);
    if (type != V_ASN1_SET) {
        if (error != NULL) {
            *error = [self _errorWithCode:ZTReceiptErrorReceiptInvalid
                                    title:@"Receipt is Invalid"
                                  message:@"PKCS7 container payload format is invalid"];
        }
        PKCS7_free(receiptPKCS7);
        BIO_free(receiptBIO);
        return nil;
    }
    // Traverse the payload...
    while (pointer < end) {
        // Decode the sequence
        ASN1_get_object(&pointer, &length, &type, &xclass, end - pointer);
        if (type != V_ASN1_SEQUENCE) {
            break;
        }
        const unsigned char *sequence_end = pointer + length;
        long attr_type = 0;
        long attr_version = 0;
        // Decode the attribute type
        ASN1_get_object(&pointer, &length, &type, &xclass, sequence_end - pointer);
        if (type != V_ASN1_INTEGER) {
            break;
        }
        if (type == V_ASN1_INTEGER && length == 1) {
            attr_type = pointer[0];
        }
        pointer += length;
        // Decode the attribute version
        ASN1_get_object(&pointer, &length, &type, &xclass, sequence_end - pointer);
        if (type == V_ASN1_INTEGER && length == 1) {
            attr_version = pointer[0];
            attr_version = attr_version;
        }
        pointer += length;
        // Get the object and switch on type
        ASN1_get_object(&pointer, &length, &type, &xclass, sequence_end - pointer);
        // Switch on the attribute type
        switch (attr_type) {
            case BUNDLE_ID: {
                str_ptr = pointer;
                str_type = 0;
                str_length = 0;
                ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, sequence_end - str_ptr);
                if (str_type == V_ASN1_UTF8STRING) {
                    NSString *bundleIDString = [[NSString alloc] initWithBytes:str_ptr length:(NSUInteger)str_length encoding:NSUTF8StringEncoding];
                    NSData *bundleIDData = [NSData dataWithBytes:pointer length:length];
                    [receiptDict setObject:bundleIDString forKey:kReceiptBundleID];
                    [receiptDict setObject:bundleIDData forKey:kReceiptBundleIDData];
                }
                break;
            }
            case VERSION: {
                str_ptr = pointer;
                str_type = 0;
                str_length = 0;
                ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, sequence_end - str_ptr);
                if (str_type == V_ASN1_UTF8STRING) {
                    NSString *versionString = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSUTF8StringEncoding];
                    [receiptDict setObject:versionString forKey:kReceiptVersion];
                }
                break;
            }
            case OPAQUE_VALUE: {
                NSData *data = [NSData dataWithBytes:pointer length:length];
                [receiptDict setObject:data forKey:kReceiptOpaqueValue];
                break;
            }
            case HASH: {
                NSData *data = [NSData dataWithBytes:pointer length:length];
                [receiptDict setObject:data forKey:kReceiptHashValue];
                break;
            }
            case ORIGINAL_VERSION: {
                str_ptr = pointer;
                str_type = 0;
                str_length = 0;
                ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, sequence_end - str_ptr);
                if (str_type == V_ASN1_UTF8STRING) {
                    NSString *versionString = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSUTF8StringEncoding];
                    [receiptDict setObject:versionString forKey:kReceiptOriginalVersion];
                }
                break;
            }
            case INAPP_PURCHASE: {
                NSData *data = [NSData dataWithBytes:pointer length:(NSUInteger)length];
                NSDictionary *purchases = [self _parseInAppPurchaseData:data];
                NSMutableArray <NSDictionary *> *existingPurchases = [receiptDict objectForKey:kReceiptInAppPurchases];
                if (existingPurchases) {
                    // if we already have something in there (i.e. there are multiple in app purchases)
                    // grab what we have in there and append to it
                    // now include our newly found IAP
                    NSArray *allPurchases = [existingPurchases arrayByAddingObject:purchases];
                    [receiptDict setObject:allPurchases forKey:kReceiptInAppPurchases];
                } else {
                    [receiptDict setObject:@[purchases] forKey:kReceiptInAppPurchases];
                }
                break;
            }
            default:
                break;
        }
        pointer += length;
        while (pointer < sequence_end) {
            ASN1_get_object(&pointer, &length, &type, &xclass, sequence_end - pointer);
            pointer += length;
        }
    }
    PKCS7_free(receiptPKCS7);
    BIO_free(receiptBIO);
    NSDictionary *finalDictionary = [NSDictionary dictionaryWithDictionary:receiptDict];
    // lastly check to make sure the receipt is for this device
    if ([self _doesHashMatchFromReceipt:finalDictionary] == NO) {
        if (error != NULL) {
            *error = [self _errorWithCode:ZTReceiptErrorReceiptInvalid
                                    title:@"Receipt is Invalid"
                                  message:@"Receipt hash doesn't match for this device"];
        }
        return nil;
    } else if ([self _doesBundleIDMatchFromReceipt:finalDictionary] == NO) { // ane make sure it's our bundle id
        if (error != NULL) {
            *error = [self _errorWithCode:ZTReceiptErrorReceiptInvalid
                                    title:@"Receipt is Invalid"
                                  message:@"Receipt bundle IDdoesn't match bundle ID"];
        }
        return nil;
    } else if ([self _doesVersionMatchFromReceipt:finalDictionary] == NO) {
        if (error != NULL) {
            *error = [self _errorWithCode:ZTReceiptErrorReceiptInvalid
                                    title:@"Receipt is Invalid"
                                  message:@"Receipt version doesn't match current version"];
        }
        return nil;
    }
    return finalDictionary;
}

- (NSDictionary *)_parseInAppPurchaseData:(NSData *)data {
    // Convenience reference to our out parameter
    int type = 0;
    int xclass = 0;
    long length = 0;
    const uint8_t *p = [data bytes];
    const uint8_t *end = p + [data length];
    int str_type = 0;
    long str_length = 0;
    const uint8_t *str_p = p;
    // setup our dictionary
    NSMutableDictionary *inAppDict = [NSMutableDictionary dictionaryWithCapacity:6];
    while (p < end) {
        // First up, this is a SET
        ASN1_get_object(&p, &length, &type, &xclass, end - p);
        const uint8_t *set_end = p + length;
        if (type != V_ASN1_SET) {
            break;
        }
        while (p < set_end) {
            ASN1_get_object(&p, &length, &type, &xclass, set_end - p);
            if (type != V_ASN1_SEQUENCE) {
                break;
            }
            const uint8_t *sequence_end = p + length;
            // Get the attribute type
            int attr_type = 0;
            ASN1_get_object(&p, &length, &type, &xclass, sequence_end - p);
            if (type == V_ASN1_INTEGER) {
                if(length == 1) {
                    attr_type = p[0];
                }
                else if(length == 2) {
                    attr_type = p[0] * 0x100 + p[1]
                    ;
                }
            }
            p += length;
            // Attribute version
            int attr_version = 0;
            ASN1_get_object(&p, &length, &type, &xclass, sequence_end - p);
            if (type == V_ASN1_INTEGER && length == 1) {
                attr_version = p[0];
            }
            p += length;
            // Let's see what we got...
            ASN1_get_object(&p, &length, &type, &xclass, sequence_end - p);
            if (type != V_ASN1_OCTET_STRING) {
                break;
            }
            switch (attr_type) {
                case INAPP_QTY: {
                    int number_type = 0;
                    long number_length = 0;
                    const uint8_t *number_p = p;
                    ASN1_get_object(&number_p, &number_length, &number_type, &xclass, sequence_end - number_p);
                    if (number_type == V_ASN1_INTEGER) {
                        NSUInteger quantity = 0;
                        quantity += number_p[0];
                        if (number_length > 1) {
                            quantity += number_p[1] * 0x100;
                            if (number_length > 2) {
                                quantity += number_p[2] * 0x10000;
                                if (number_length > 3) {
                                    quantity += number_p[3] * 0x1000000;
                                }
                            }
                        }
                        NSNumber *number = [NSNumber numberWithUnsignedInteger:quantity];
                        [inAppDict setObject:number forKey:kReceiptInAppQuantity];
                    }
                    break;
                }
                case INAPP_PRODUCT_ID: {
                    str_type = 0;
                    str_length = 0;
                    str_p = p;
                    ASN1_get_object(&str_p, &str_length, &str_type, &xclass, sequence_end - str_p);
                    NSString *productID = [[NSString alloc] initWithBytes:str_p length:(NSUInteger)str_length encoding:NSUTF8StringEncoding];
                    [inAppDict setObject:productID forKey:kReceiptInAppProductID];
                    break;
                }
                case INAPP_TRANSACTION_ID: {
                    str_type = 0;
                    str_length = 0;
                    str_p = p;
                    ASN1_get_object(&str_p, &str_length, &str_type, &xclass, sequence_end - str_p);
                    NSString *transactionID = [[NSString alloc] initWithBytes:str_p length:(NSUInteger)str_length encoding:NSUTF8StringEncoding];
                    [inAppDict setObject:transactionID forKey:kReceiptInAppTransactionID];
                    break;
                }
                case INAPP_PURCHASE_DATE: {
                    str_type = 0;
                    str_length = 0;
                    str_p = p;
                    ASN1_get_object(&str_p, &str_length, &str_type, &xclass, sequence_end - str_p);
                    // The date objects are ASCII encoded
                    NSString *purchaseDateString = [[NSString alloc] initWithBytes:str_p
                                                                            length:(NSUInteger)str_length
                                                                          encoding:NSASCIIStringEncoding];
                    [inAppDict setObject:purchaseDateString forKey:kReceiptInAppPurchaseDate];
                    break;
                }
                case INAPP_ORIGINAL_TRANSACTION_ID: {
                    str_type = 0;
                    str_length = 0;
                    str_p = p;
                    ASN1_get_object(&str_p, &str_length, &str_type, &xclass, sequence_end - str_p);
                    NSString *transactionID = [[NSString alloc] initWithBytes:str_p length:(NSUInteger)str_length encoding:NSUTF8StringEncoding];
                    [inAppDict setObject:transactionID forKey:kReceiptInAppOriginalTransactionID];
                    break;
                }
                case INAPP_ORIGINAL_PURCHASE_DATE: {
                    str_type = 0;
                    str_length = 0;
                    str_p = p;
                    ASN1_get_object(&str_p, &str_length, &str_type, &xclass, sequence_end - str_p);
                    // The date objects are ASCII encoded
                    NSString *purchaseDateString = [[NSString alloc] initWithBytes:str_p
                                                                            length:(NSUInteger)str_length
                                                                          encoding:NSASCIIStringEncoding];
                    [inAppDict setObject:purchaseDateString forKey:kReceiptInAppOriginalPurchaseDate];
                    break;
                }
                default:
                    break;
            }
            p += length;
            while (p < sequence_end) {
                ASN1_get_object(&p, &length, &type, &xclass, sequence_end - p);
                p += length;
            }
        }
        while (p < set_end) {
            ASN1_get_object(&p, &length, &type, &xclass, set_end - p);
            p += length;
        }
    }
    return inAppDict;
}

- (BOOL)_doesHashMatchFromReceipt:(NSDictionary *)receipt {
    NSData *bundleIDData = [receipt objectForKey:kReceiptBundleIDData];
    NSData *opaqueValueData = [receipt objectForKey:kReceiptOpaqueValue];
    NSUUID *uuid = [[UIDevice currentDevice] identifierForVendor];
    uuid_t uuidBytes;
    [uuid getUUIDBytes:uuidBytes];
    NSMutableData *totalData = [NSMutableData dataWithBytes:uuidBytes length:sizeof(uuidBytes)];
    [totalData appendData:opaqueValueData];
    [totalData appendData:bundleIDData];
    unsigned char digestBuffer[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(totalData.bytes, (CC_LONG)totalData.length, digestBuffer);
    NSData *hashFromReceipt = [receipt objectForKey:kReceiptHashValue];
    if (memcmp(digestBuffer, hashFromReceipt.bytes, CC_SHA1_DIGEST_LENGTH) == 0) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)_doesBundleIDMatchFromReceipt:(NSDictionary *)receipt {
    NSString *bundleIDString = [receipt objectForKey:kReceiptBundleID];
    return [bundleIDString isEqualToString:kBubblyBundleID];
}

- (BOOL)_doesVersionMatchFromReceipt:(NSDictionary *)receipt {
    NSString *version = [receipt objectForKey:kReceiptVersion];
    return [version isEqualToString:kBubblyCurrentVersion];
}

- (NSError *)_errorWithCode:(ZTReceiptError)code title:(NSString *)title message:(NSString *)message {
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : title,
                                NSLocalizedFailureReasonErrorKey: message };
    NSError *error = [NSError errorWithDomain:ZSBubblyReceiptValidatorErrorDomain code:code userInfo:userInfo];
    return error;
}
@end

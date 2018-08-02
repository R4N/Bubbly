//
//  ZTLicenseState.h
//  Bubbly
//
//  Created by Micah T. Moore on 8/1/18.
//  Copyright © 2018 Zetetic LLC. All rights reserved.
//

#ifndef ZTLicenseState_h
#define ZTLicenseState_h

typedef NS_ENUM(NSUInteger, ZTLicenseState) {
    ZTLicenseStateNone = 1,
    ZTLicenseStateTrial,
    ZTLicenseStateTrialExpired,
    ZTLicenseStateValidated,
};

#endif /* ZTLicenseState_h */

//
//  Foundation+LocalizationAdditions.m
//  Proton
//
//  Created by James Lawton on 12/6/11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/Foundation+LocalizationAdditions.h>

NSString *PROLocalizedStringWithDefaultValue(NSString *key, NSString *value, NSString *comment) {
    return NSLocalizedStringWithDefaultValue(key, nil, [NSBundle mainBundle], value, comment);
}

//
//  Foundation+LocalizationAdditions.h
//  Proton
//
//  Created by James Lawton on 12/6/11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//


/**
 * Returns a localized string from the default table in the main bundle.
 *
 * If no such string is found, `value` will be returned.
 *
 * @param key The key to look up in the localization table.
 * @param value The default value, returned if the key was not found for the current language.
 * @param comment A note which will appear in the localized strings file, to help with context.
 */
NSString *PROLocalizedStringWithDefaultValue(NSString *key, NSString *value, NSString *comment);

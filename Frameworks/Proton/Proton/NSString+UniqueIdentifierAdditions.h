//
//  NSString+UniqueIdentifierAdditions.h
//  Proton
//
//  Created by James Lawton on 12/13/11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (UniqueIdentifierAdditions)

/**
 * Returns a new string that is very probably unique.
 */
+ (NSString *)UUID;

@end

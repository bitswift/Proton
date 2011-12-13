//
//  NSString+UniqueIdentifierAdditions.m
//  Proton
//
//  Created by James Lawton on 12/13/11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "NSString+UniqueIdentifierAdditions.h"

@implementation NSString (UniqueIdentifierAdditions)

+ (NSString *)UUID {
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef stringRef = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);

    // Copy isn't necessary, but Clang gets upset
    NSString *string = [NSString stringWithString:(__bridge NSString *)stringRef];
    CFRelease(stringRef);

    return string;
}

@end

//
//  NSObject+ErrorAdditions.m
//  Proton
//
//  Created by James Lawton on 12/6/11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import "NSObject+ErrorAdditions.h"
#import "EXTSafeCategory.h"
#import "PROAssert.h"

@interface NSObject (DummyMethods)
/*
 * This declaration is required so that we have the signature information to use `errorDomain`. It will
 * actually be implemented on the specific class of the receiver.
 */
+ (NSString *)errorDomain;
@end

@safecategory (NSObject, ErrorAdditions)

- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description recoverySuggestion:(NSString *)recoverySuggestion {

    if (!PROAssert([[self class] respondsToSelector:@selector(errorDomain)], @"Receiver's class (%@) must respond to errorDomain", NSStringFromClass([self class]))) {
        return nil;
    }

    NSString *errorDomain = @"PRODefaultErrorDomain";
    if ([[self class] respondsToSelector:@selector(errorDomain)]) {
        errorDomain = [[self class] errorDomain];
    }

    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        description, NSLocalizedDescriptionKey,
        recoverySuggestion, NSLocalizedRecoverySuggestionErrorKey,
        nil
    ];

    return [NSError errorWithDomain:errorDomain code:code userInfo:userInfo];
}

@end

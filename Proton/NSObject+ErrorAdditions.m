//
//  NSObject+ErrorAdditions.m
//  Proton
//
//  Created by James Lawton on 12/6/11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Proton/NSObject+ErrorAdditions.h>
#import <Proton/EXTSafeCategory.h>

@interface NSObject (DummyMethods)
/*
 * This declaration is required so that we have the signature information to use `errorDomain`. It will
 * actually be implemented on the specific class of the receiver.
 */
+ (NSString *)errorDomain;
@end

@safecategory (NSObject, ErrorAdditions)

- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description recoverySuggestion:(NSString *)recoverySuggestion {

    NSAssert([[self class] respondsToSelector:@selector(errorDomain)], @"Receiver's class (%@) must respond to errorDomain", NSStringFromClass([self class]));

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

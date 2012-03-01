//
//  NSError+ValidationAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 01.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSError+ValidationAdditions.h"
#import "EXTSafeCategory.h"

@safecategory (NSError, ValidationAdditions)

- (NSError *)multipleValidationErrorByAddingError:(NSError *)error; {
    NSParameterAssert(error != nil);

    NSArray *errors = nil;
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];

    if ([self.domain isEqualToString:NSCocoaErrorDomain] && self.code == NSValidationMultipleErrorsError) {
        userInfo = [self.userInfo mutableCopy];

        NSArray *existingErrors = [self.userInfo objectForKey:NSDetailedErrorsKey];
        if (existingErrors)
            errors = [existingErrors arrayByAddingObject:error];
    }

    if (!errors)
        errors = [NSArray arrayWithObjects:self, error, nil];

    [userInfo setObject:errors forKey:NSDetailedErrorsKey];

    return [[self class]
        errorWithDomain:NSCocoaErrorDomain
        code:NSValidationMultipleErrorsError
        userInfo:userInfo
    ];
}

@end

//
//  PRONSErrorAdditionsTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 01.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/NSError+ValidationAdditions.h>

SpecBegin(PRONSErrorAdditions)
    
    describe(@"creating multiple validation errors", ^{
        __block NSError *result;
        __block NSArray *validationErrors;

        __block NSError *(^validationErrorWithKey)(NSString *key);
        
        before(^{
            result = nil;
            validationErrors = nil;

            validationErrorWithKey = [^(NSString *key){
                return [NSError
                    errorWithDomain:NSCocoaErrorDomain
                    code:NSManagedObjectValidationError
                    userInfo:[NSDictionary dictionaryWithObject:key forKey:NSValidationKeyErrorKey]
                ];
            } copy];
        });

        after(^{
            expect(result).not.toBeNil();
            expect(result.domain).toEqual(NSCocoaErrorDomain);
            expect(result.code).toEqual(NSValidationMultipleErrorsError);

            NSArray *detailedErrors = [result.userInfo objectForKey:NSDetailedErrorsKey];
            expect(detailedErrors).toEqual(validationErrors);
        });

        it(@"should combine two validation errors", ^{
            validationErrors = [NSArray arrayWithObjects:
                validationErrorWithKey(@"first"),
                validationErrorWithKey(@"second"),
                nil
            ];

            result = [[validationErrors objectAtIndex:0] multipleValidationErrorByAddingError:validationErrors.lastObject];
        });

        it(@"should combine a multiple validation error with another error", ^{
            validationErrors = [NSArray arrayWithObjects:
                validationErrorWithKey(@"first"),
                validationErrorWithKey(@"second"),
                nil
            ];

            result = [[validationErrors objectAtIndex:0] multipleValidationErrorByAddingError:validationErrors.lastObject];

            validationErrors = [validationErrors arrayByAddingObject:validationErrorWithKey(@"third")];
            result = [result multipleValidationErrorByAddingError:validationErrors.lastObject];
        });
    });

SpecEnd

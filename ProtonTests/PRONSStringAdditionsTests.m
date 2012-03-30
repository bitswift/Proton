//
//  PRONSStringAdditionsTests.m
//  Proton
//
//  Created by James Lawton on 2/14/12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/NSString+NumericSuffixAdditions.h>

SpecBegin(PRONSStringAdditions)

    NSSet *nonconflicting = [NSSet setWithObjects:
        @"Screen 2.", @"foo", @"bar",
        nil
    ];
    NSSet *conflicting = [NSSet setWithObjects:
        @"Screen",    @"Screen 1",  @"Sc 10",
        @"Screen 2",  @"Screen 3",  @"Screen 4",
        @"Screen 5",  @"Screen 6",  @"Screen 7",
        @"Screen 8",  @"Screen 9",  @"Screen 10",
        @"Screen 12", @"Screen 13", @"Screen 14",
        nil
    ];

    it(@"leaves the string alone if there are no conflicts", ^{
        NSString *original = @"Screen";
        NSString *string = [original stringByAddingNumericSuffixNotConflictingWithStrings:nonconflicting];
        expect(string).toEqual(@"Screen");
    });

    it(@"appends 2 if there is no numeric suffix to begin with", ^{
        NSString *original = @"Screen";
        NSSet *conflictsWithOriginalString = [nonconflicting setByAddingObject:original];
        NSString *string = [original stringByAddingNumericSuffixNotConflictingWithStrings:conflictsWithOriginalString];
        expect(string).toEqual(@"Screen 2");
    });

    it(@"increases the numeric suffix by 1", ^{
        NSString *original = @"Screen 19";
        NSSet *conflictsWithOriginalString = [nonconflicting setByAddingObject:original];
        NSString *string = [original stringByAddingNumericSuffixNotConflictingWithStrings:conflictsWithOriginalString];
        expect(string).toEqual(@"Screen 20");
    });

    it(@"picks the next smallest non-conflicting suffix", ^{
        NSString *string = [@"Screen" stringByAddingNumericSuffixNotConflictingWithStrings:conflicting];
        expect(string).toEqual(@"Screen 11");
    });

    it(@"constrains the output to the given max characters", ^{
        NSString *string = [@"Screen" stringByAddingNumericSuffixNotConflictingWithStrings:conflicting constrainedToLength:5];
        NSString *string2 = [@"Screen 9" stringByAddingNumericSuffixNotConflictingWithStrings:conflicting constrainedToLength:5];
        expect(string).toEqual(@"Scr 2");
        expect(string2).toEqual(@"Sc 11");
    });

SpecEnd

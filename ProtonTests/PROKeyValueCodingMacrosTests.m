//
//  PROKeyValueCodingMacrosTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 23.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Proton/PROKeyValueCodingMacros.h>

@interface KVCTestClass : NSObject
@property (nonatomic, strong) NSString *someProperty;
@property (nonatomic, assign) NSRange range;
@end

SpecBegin(PROKeyValueCodingMacros)
    
    describe(@"PROKeyForObject", ^{
        KVCTestClass *obj = [[KVCTestClass alloc] init];

        __block NSString *key = nil;

        after(^{
            expect(key).not.toBeNil();

            // make sure looking up this key path doesn't throw an exception
            [obj valueForKeyPath:key];
        });

        it(@"should return a valid string for object key", ^{
            key = PROKeyForObject(obj, someProperty);
        });

        it(@"should return a valid string for object key path", ^{
            key = PROKeyForObject(obj, someProperty.length);
        });

        it(@"should return a valid string for struct key", ^{
            key = PROKeyForObject(obj, range);
        });
    });

    describe(@"PROKeyForClass", ^{
        __block NSString *key = nil;

        after(^{
            expect(key).not.toBeNil();

            KVCTestClass *obj = [[KVCTestClass alloc] init];
            
            // make sure looking up this key path doesn't throw an exception
            [obj valueForKeyPath:key];
        });

        it(@"should return a valid string for object key", ^{
            key = PROKeyForClass(KVCTestClass, someProperty);
        });

        it(@"should return a valid string for object key path", ^{
            key = PROKeyForClass(KVCTestClass, someProperty.length);
        });

        it(@"should return a valid string for struct key", ^{
            key = PROKeyForClass(KVCTestClass, range);
        });
    });

SpecEnd

@implementation KVCTestClass
@synthesize someProperty = m_someProperty;
@synthesize range = m_range;
@end


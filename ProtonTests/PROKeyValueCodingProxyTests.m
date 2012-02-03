//
//  PROKeyValueCodingProxyTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 03.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/PROKeyValueCodingProxy.h>
#import <Proton/EXTNil.h>

SpecBegin(PROKeyValueCodingProxy)

    __block EXTNil *proxiedObject;

    before(^{
        proxiedObject = [EXTNil null];
    });

    it(@"should initialize without a key path", ^{
        PROKeyValueCodingProxy *proxy = [[PROKeyValueCodingProxy alloc] initWithProxiedObject:proxiedObject];
        expect(proxy).not.toBeNil();

        expect(proxy.proxiedObject).toEqual(proxiedObject);
        expect(proxy.proxiedKeyPath).toBeNil();
    });

    it(@"should initialize with a key path", ^{
        PROKeyValueCodingProxy *proxy = [[PROKeyValueCodingProxy alloc] initWithProxiedObject:proxiedObject keyPath:@"foo.bar"];
        expect(proxy).not.toBeNil();

        expect(proxy.proxiedObject).toEqual(proxiedObject);
        expect(proxy.proxiedKeyPath).toEqual(@"foo.bar");
    });

    describe(@"callbacks", ^{
        __block PROKeyValueCodingProxy *proxy;
        __block NSMutableDictionary *dictionary;

        before(^{
            proxy = [[PROKeyValueCodingProxy alloc] init];
            expect(proxy).not.toBeNil();

            __weak PROKeyValueCodingProxy *weakProxy = proxy;

            NSMutableArray *bazArray = [NSMutableArray arrayWithObject:@"baz"];

            dictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                @"bar", @"foo",
                @"buzz", @"fizz",
                bazArray, @"baz",
                nil
            ];

            proxy.setValueForKeyPathBlock = ^(id value, NSString *keyPath){
                [dictionary setValue:value forKeyPath:keyPath];
            };

            proxy.valueForKeyPathBlock = ^(NSString *keyPath){
                id value = [dictionary valueForKeyPath:keyPath];
                if (value)
                    return value;

                PROKeyValueCodingProxy *nestedProxy = [weakProxy proxyWithObject:proxiedObject keyPath:keyPath];
                expect(nestedProxy).not.toBeNil();

                expect(nestedProxy.setValueForKeyPathBlock).toEqual(weakProxy.setValueForKeyPathBlock);
                expect(nestedProxy.valueForKeyPathBlock).toEqual(weakProxy.valueForKeyPathBlock);
                expect(nestedProxy.mutableArrayValueForKeyPathBlock).toEqual(weakProxy.mutableArrayValueForKeyPathBlock);
                
                return nestedProxy;
            };

            proxy.mutableArrayValueForKeyPathBlock = ^(NSString *keyPath){
                return [dictionary mutableArrayValueForKeyPath:keyPath];
            };
        });

        it(@"should forward unrecognized messages to the proxied object", ^{
            expect([(id)proxy length]).toEqual(0);
            expect([(id)proxy stringByAppendingString:@"foobar"]).toBeNil();
        });

        it(@"should retrieve a value for a key", ^{
            expect([proxy valueForKey:@"fizz"]).toEqual([dictionary objectForKey:@"fizz"]);
        });

        it(@"should retrieve an array value for a key", ^{
            NSMutableArray *array = [proxy mutableArrayValueForKey:@"baz"];
            expect(array).toEqual([dictionary objectForKey:@"baz"]);

            [array addObject:@"null"];
            NSArray *expectedArray = [NSArray arrayWithObjects:@"baz", @"null", nil];

            expect(array).toEqual(expectedArray);
            expect([dictionary objectForKey:@"baz"]).toEqual(expectedArray);
        });

        it(@"should set a value for a key", ^{
            [proxy setValue:[NSNull null] forKey:@"foo"];
            expect([dictionary objectForKey:@"foo"]).toEqual([NSNull null]);
        });

        describe(@"key paths", ^{
            __block NSMutableDictionary *nestedDictionary;

            before(^{
                NSMutableArray *nestedArray = [NSMutableArray arrayWithObject:[NSNumber numberWithInt:1]];

                nestedDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                    nestedArray, @"nestedArray",
                    [NSNumber numberWithBool:YES], @"isTrue",
                    nil
                ];

                [dictionary setObject:nestedDictionary forKey:@"nestedDictionary"];
            });

            it(@"should retrieve a value for a key path", ^{
                expect([proxy valueForKeyPath:@"nestedDictionary.isTrue"]).toEqual([nestedDictionary objectForKey:@"isTrue"]);
            });

            it(@"should retrieve an array value for a key path", ^{
                NSMutableArray *array = [proxy mutableArrayValueForKeyPath:@"nestedDictionary.nestedArray"];
                expect(array).toEqual([nestedDictionary objectForKey:@"nestedArray"]);

                [array removeObjectAtIndex:0];
                NSArray *expectedArray = [NSArray array];

                expect(array).toEqual(expectedArray);
                expect([nestedDictionary objectForKey:@"nestedArray"]).toEqual(expectedArray);
            });

            it(@"should set a value for a key", ^{
                [proxy setValue:nil forKeyPath:@"nestedDictionary.nestedArray"];
                expect([nestedDictionary objectForKey:@"nestedArray"]).toBeNil();
            });
        });
    });

SpecEnd

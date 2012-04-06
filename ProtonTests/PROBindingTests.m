//
//  PROBindingTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 31.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/PROBinding.h>

static NSString * const NonKVOCompliantObjectErrorDomain = @"NonKVOCompliantObjectErrorDomain";
static const NSInteger NonKVOCompliantObjectValidationError = 1;

static NSString * const NonKVOCompliantObjectReplaceableValue = @"replace me!";
static NSString * const NonKVOCompliantObjectReplacedValue = @"replaced value";

@interface NonKVOCompliantObject : NSObject
@property (nonatomic, copy) NSString *value;

// validates that the length of the given string is less than 20 characters
- (BOOL)validateValue:(NSString **)valuePtr error:(NSError **)error;
@end

@interface CustomBindingClass : PROBinding
@end

SpecBegin(PROBinding)

    describe(@"KVO changes", ^{
        __block NSMutableDictionary *owner;
        __block NSString *ownerKeyPath;
        
        __block NSMutableDictionary *boundObject;
        __block NSString *boundKeyPath;

        before(^{
            @autoreleasepool {
                NSMutableDictionary *nestedDictionary = [NSMutableDictionary dictionaryWithObject:[NSNull null] forKey:@"foo"];
                owner = [NSMutableDictionary dictionaryWithObject:nestedDictionary forKey:@"nested"];
                ownerKeyPath = @"nested.foo";

                boundObject = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:5] forKey:@"bar"];
                boundKeyPath = @"bar";

                expect([owner valueForKeyPath:ownerKeyPath]).not.toEqual([boundObject valueForKeyPath:boundKeyPath]);
            }
        });

        it(@"should not update the owner when bound with the initializer", ^{
            PROBinding *binding = [[PROBinding alloc] initWithOwner:owner ownerKeyPath:ownerKeyPath boundObject:boundObject boundKeyPath:boundKeyPath];
            expect(binding).not.toBeNil();

            expect([owner valueForKeyPath:ownerKeyPath]).not.toEqual([boundObject valueForKeyPath:boundKeyPath]);
            [binding unbind];
        });

        it(@"should not be retained by the owner when using the initializer", ^{
            __weak id weakBinding = nil;

            @autoreleasepool {
                __attribute__((objc_precise_lifetime)) PROBinding *binding = [[PROBinding alloc] initWithOwner:owner ownerKeyPath:ownerKeyPath boundObject:boundObject boundKeyPath:boundKeyPath];

                weakBinding = binding;
                expect(weakBinding).not.toBeNil();
                [weakBinding unbind];
            }

            expect(weakBinding).toBeNil();
        });

        it(@"should be retained by the owner when using the class constructor", ^{
            __weak id weakBinding = nil;

            @autoreleasepool {
                __attribute__((objc_precise_lifetime)) PROBinding *binding = [PROBinding bindKeyPath:ownerKeyPath ofObject:owner toKeyPath:boundKeyPath ofObject:boundObject];

                weakBinding = binding;
                expect(weakBinding).not.toBeNil();
            }

            @autoreleasepool {
                expect(weakBinding).not.toBeNil();

                [weakBinding unbind];
            }

            expect(weakBinding).toBeNil();
        });

        it(@"should instantiate a custom subclass when bound with the class constructor", ^{
            CustomBindingClass *binding = [CustomBindingClass bindKeyPath:ownerKeyPath ofObject:owner toKeyPath:boundKeyPath ofObject:boundObject];
            expect(binding).toBeKindOf([CustomBindingClass class]);

            [binding unbind];
        });

        it(@"should transform bound values with a block added in a setup block", ^{
            id boundValue = [boundObject valueForKeyPath:boundKeyPath];

            PROBinding *binding = [PROBinding bindKeyPath:ownerKeyPath ofObject:owner toKeyPath:boundKeyPath ofObject:boundObject withSetup:^(PROBinding *binding){
                binding.boundValueTransformationBlock = ^ id (id value){
                    return nil;
                };
            }];

            expect([owner valueForKeyPath:ownerKeyPath]).toBeNil();
            expect([boundObject valueForKeyPath:boundKeyPath]).toEqual(boundValue);

            [binding unbind];
        });

        describe(@"with an instance", ^{
            __block __weak PROBinding *binding;

            before(^{
                @autoreleasepool {
                    binding = [PROBinding bindKeyPath:ownerKeyPath ofObject:owner toKeyPath:boundKeyPath ofObject:boundObject];
                    expect(binding).not.toBeNil();

                    expect(binding.bound).toBeTruthy();
                    expect(binding.owner).toEqual(owner);
                    expect(binding.ownerKeyPath).toEqual(ownerKeyPath);
                    expect(binding.boundObject).toEqual(boundObject);
                    expect(binding.boundKeyPath).toEqual(boundKeyPath);
                }

                expect(binding).not.toBeNil();
            });

            after(^{
                PROBinding *retainedBinding = binding;
                [retainedBinding unbind];

                expect(retainedBinding.bound).toBeFalsy();
                expect(retainedBinding.owner).toBeNil();
                expect(retainedBinding.boundObject).toBeNil();
            });

            it(@"should update the owner when bound using the class constructor", ^{
                expect([owner valueForKeyPath:ownerKeyPath]).toEqual([boundObject valueForKeyPath:boundKeyPath]);
            });

            it(@"should update the owner when the bound object changes", ^{
                id value = @"this is a value!";

                expect([^{
                    [boundObject setValue:value forKeyPath:boundKeyPath];
                } copy]).toInvoke(binding, @selector(boundObjectChanged:));

                expect([owner valueForKeyPath:ownerKeyPath]).toEqual(value);
            });

            it(@"should update the bound object when the owner changes", ^{
                id value = @"this is a value!";

                expect([^{
                    [owner setValue:value forKeyPath:ownerKeyPath];
                } copy]).toInvoke(binding, @selector(ownerChanged:));

                expect([boundObject valueForKeyPath:boundKeyPath]).toEqual(value);
            });

            it(@"should unbind twice without issue", ^{
                PROBinding *retainedBinding = binding;
                [retainedBinding unbind];
                [retainedBinding unbind];
            });

            it(@"should remove a single binding from an owner", ^{
                [PROBinding removeAllBindingsFromOwner:owner];
                
                expect(binding.bound).toBeFalsy();
                expect(binding.owner).toBeNil();
                expect(binding.boundObject).toBeNil();
            });

            it(@"should remove all bindings from an owner", ^{
                PROBinding *anotherBinding = [PROBinding bindKeyPath:ownerKeyPath ofObject:owner toKeyPath:boundKeyPath ofObject:boundObject];
                expect(anotherBinding.bound).toBeTruthy();

                [PROBinding removeAllBindingsFromOwner:owner];
                
                expect(binding.bound).toBeFalsy();
                expect(anotherBinding.bound).toBeFalsy();
            });
        });
    });

    describe(@"manual changes", ^{
        __block NonKVOCompliantObject *owner;
        __block NonKVOCompliantObject *boundObject;

        __block __weak PROBinding *binding;

        before(^{
            owner = [[NonKVOCompliantObject alloc] init];
            expect(owner).not.toBeNil();

            boundObject = [[NonKVOCompliantObject alloc] init];
            expect(boundObject).not.toBeNil();

            owner.value = @"foo";
            boundObject.value = @"bar";

            binding = [PROBinding bindKeyPath:@"value" ofObject:owner toKeyPath:@"value" ofObject:boundObject];
            expect(binding).not.toBeNil();
        });

        after(^{
            [binding unbind];
        });

        it(@"should update the owner when bound", ^{
            expect(owner.value).toEqual(@"bar");
        });

        it(@"should not automatically update when a change occurs", ^{
            owner.value = @"fizz";

            expect(owner.value).toEqual(@"fizz");
            expect(boundObject.value).toEqual(@"bar");

            boundObject.value = @"buzz";

            expect(owner.value).toEqual(@"fizz");
            expect(boundObject.value).toEqual(@"buzz");
        });

        it(@"should push changes to the bound object when -ownerChanged: is invoked", ^{
            owner.value = @"fizz";
            boundObject.value = @"buzz";

            [binding ownerChanged:nil];

            expect(owner.value).toEqual(@"fizz");
            expect(boundObject.value).toEqual(@"fizz");
        });

        it(@"should push changes to the owner when -boundObjectChanged: is invoked", ^{
            owner.value = @"fizz";
            boundObject.value = @"buzz";

            [binding boundObjectChanged:nil];

            expect(owner.value).toEqual(@"buzz");
            expect(boundObject.value).toEqual(@"buzz");
        });

        it(@"should transform bound values using the given block", ^{
            binding.boundValueTransformationBlock = ^ id (id value){
                return nil;
            };

            boundObject.value = @"foobar";
            [binding boundObjectChanged:nil];

            expect(owner.value).toBeNil();
            expect(boundObject.value).toEqual(@"foobar");
        });

        it(@"should transform owner values using the boundValueTransformationBlock by default", ^{
            binding.boundValueTransformationBlock = ^ id (id value){
                return nil;
            };

            expect(binding.ownerValueTransformationBlock).not.toBeNil();

            owner.value = @"foobar";
            [binding ownerChanged:nil];

            expect(owner.value).toEqual(@"foobar");
            expect(boundObject.value).toBeNil();
        });

        it(@"should transform owner values using the given block", ^{
            binding.boundValueTransformationBlock = ^(id value){
                return @"fuzz";
            };

            binding.ownerValueTransformationBlock = ^ id (id value){
                return nil;
            };

            owner.value = @"foobar";
            [binding ownerChanged:nil];

            expect(owner.value).toEqual(@"foobar");
            expect(boundObject.value).toBeNil();
        });

        describe(@"validation", ^{
            NSString *invalidValue = @"this is a string that's too long to pass validation.";

            it(@"should fail to set invalid values on the owner", ^{
                boundObject.value = invalidValue;
                [binding boundObjectChanged:nil];

                expect(boundObject.value).toEqual(invalidValue);
                expect(owner.value).not.toEqual(invalidValue);
            });

            it(@"should fail to set invalid values on the bound object", ^{
                owner.value = invalidValue;
                [binding ownerChanged:nil];

                expect(boundObject.value).not.toEqual(invalidValue);
                expect(owner.value).toEqual(invalidValue);
            });

            it(@"should use a new value returned from a validation method on the owner", ^{
                boundObject.value = NonKVOCompliantObjectReplaceableValue;
                [binding boundObjectChanged:nil];

                expect(boundObject.value).toEqual(NonKVOCompliantObjectReplaceableValue);
                expect(owner.value).toEqual(NonKVOCompliantObjectReplacedValue);
            });

            it(@"should use a new value returned from a validation method on the bound object", ^{
                owner.value = NonKVOCompliantObjectReplaceableValue;
                [binding ownerChanged:nil];

                expect(boundObject.value).toEqual(NonKVOCompliantObjectReplacedValue);
                expect(owner.value).toEqual(NonKVOCompliantObjectReplaceableValue);
            });

            it(@"should invoke a custom validation block when the owner fails validation", ^{
                __block BOOL validationBlockInvoked = NO;

                binding.validationFailedBlock = ^(id object, NSString *keyPath, id value, NSError *error){
                    validationBlockInvoked = YES;

                    expect(object).toEqual(owner);
                    expect(keyPath).toEqual(@"value");
                    expect(value).toEqual(invalidValue);

                    expect(error.domain).toEqual(NonKVOCompliantObjectErrorDomain);
                    expect(error.code).toEqual(NonKVOCompliantObjectValidationError);
                };

                boundObject.value = invalidValue;
                [binding boundObjectChanged:nil];

                expect(validationBlockInvoked).toBeTruthy();
            });

            it(@"should invoke a custom validation block when the bound object fails validation", ^{
                __block BOOL validationBlockInvoked = NO;

                binding.validationFailedBlock = ^(id object, NSString *keyPath, id value, NSError *error){
                    validationBlockInvoked = YES;

                    expect(object).toEqual(boundObject);
                    expect(keyPath).toEqual(@"value");
                    expect(value).toEqual(invalidValue);

                    expect(error.domain).toEqual(NonKVOCompliantObjectErrorDomain);
                    expect(error.code).toEqual(NonKVOCompliantObjectValidationError);
                };

                owner.value = invalidValue;
                [binding ownerChanged:nil];

                expect(validationBlockInvoked).toBeTruthy();
            });
        });
    });

SpecEnd

@implementation NonKVOCompliantObject : NSObject
@synthesize value = m_value;

- (NSString *)value {
    return m_value;
}

- (void)setValue:(NSString *)value {
    m_value = [value copy];
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    return NO;
}

- (BOOL)validateValue:(NSString **)valuePtr error:(NSError **)error; {
    NSString *value = *valuePtr;
    if ([value isEqualToString:NonKVOCompliantObjectReplaceableValue]) {
        *valuePtr = NonKVOCompliantObjectReplacedValue;
        return YES;
    }

    if (!value || [value length] < 20)
        return YES;

    if (error) {
        *error = [NSError errorWithDomain:NonKVOCompliantObjectErrorDomain code:NonKVOCompliantObjectValidationError userInfo:nil];
    }

    return NO;
}

@end

@implementation CustomBindingClass
@end

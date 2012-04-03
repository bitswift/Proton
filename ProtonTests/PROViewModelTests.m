//
//  PROViewViewModelTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 03.04.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/Proton.h>

@interface TestViewModel : PROViewModel {
    BOOL m_initWithCoderInvoked;
}

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSDate *date;
@property (nonatomic, getter = isEnabled) BOOL enabled;

- (void)someAction:(id)sender;
- (BOOL)validateSomeAction;
@end

@interface CollectionTestViewModel : PROViewModel
@property (nonatomic, copy) NSArray *array;
@property (nonatomic, copy) NSDictionary *dictionary;
@property (nonatomic, copy) NSOrderedSet *orderedSet;
@property (nonatomic, copy) NSSet *set;
@end

SpecBegin(PROViewModel)

    describe(@"base class", ^{
        it(@"has no propertyKeys", ^{
            expect([PROViewModel propertyKeys]).toEqual([NSArray array]);
        });

        it(@"has no defaultValuesForKeys", ^{
            expect([PROViewModel defaultValuesForKeys]).toEqual([NSDictionary dictionary]);
        });
    });

    describe(@"TestViewModel subclass", ^{
        it(@"has propertyKeys", ^{
            expect([TestViewModel propertyKeys]).toContain(@"name");
            expect([TestViewModel propertyKeys]).toContain(@"date");
            expect([TestViewModel propertyKeys]).toContain(@"enabled");

            expect([TestViewModel propertyKeys]).not.toContain(@"array");
        });

        it(@"has no defaultValuesForKeys", ^{
            expect([TestViewModel defaultValuesForKeys]).toEqual([NSDictionary dictionary]);
        });

        it(@"initializes", ^{
            TestViewModel *viewModel = [[TestViewModel alloc] init];
            expect(viewModel).not.toBeNil();

            expect(viewModel.model).toBeNil();
            expect(viewModel.name).toBeNil();
            expect(viewModel.date).toBeNil();
            expect(viewModel.enabled).toBeFalsy();
            expect(viewModel.initializingFromArchive).toBeFalsy();

            expect([viewModel.dictionaryValue objectForKey:@"name"]).toEqual([NSNull null]);
            expect([viewModel.dictionaryValue objectForKey:@"date"]).toEqual([NSNull null]);
            expect([[viewModel.dictionaryValue objectForKey:@"enabled"] boolValue]).toBeFalsy();
        });

        it(@"initializes with a model", ^{
            NSMutableArray *array = [NSMutableArray array];

            TestViewModel *viewModel = [[TestViewModel alloc] initWithModel:array];
            expect(viewModel).not.toBeNil();

            expect(viewModel.model).toEqual(array);
            expect(viewModel.name).toBeNil();
            expect(viewModel.date).toBeNil();
            expect(viewModel.enabled).toBeFalsy();
            expect(viewModel.initializingFromArchive).toBeFalsy();
        });

        describe(@"initialized with dictionary", ^{
            NSDictionary *initializationDictionary = [NSDictionary dictionaryWithObject:@"foobar" forKey:@"name"];

            __block TestViewModel *viewModel = nil;

            before(^{
                viewModel = [[TestViewModel alloc] initWithDictionary:initializationDictionary];
                expect(viewModel).not.toBeNil();

                viewModel.model = [NSMutableArray array];
                expect(viewModel.model).not.toBeNil();

                expect([viewModel valueForKey:@"name"]).toEqual(@"foobar");
            });

            it(@"has correct dictionary value", ^{
                NSDictionary *expectedDictionaryValue = [NSDictionary dictionaryWithObjectsAndKeys:
                    @"foobar", @"name",
                    [NSNull null], @"date",
                    [NSNumber numberWithBool:NO], @"enabled",
                    nil
                ];

                expect(viewModel.dictionaryValue).toEqual(expectedDictionaryValue);
            });

            it(@"is equal to same view model data", ^{
                TestViewModel *otherViewModel = [[TestViewModel alloc] initWithDictionary:initializationDictionary];
                expect(viewModel).not.toEqual(otherViewModel);

                otherViewModel.model = viewModel.model;
                expect(viewModel).toEqual(otherViewModel);
            });

            it(@"is not equal to a different view model", ^{
                TestViewModel *otherViewModel = [[TestViewModel alloc] initWithModel:viewModel.model];
                expect(viewModel).not.toEqual(otherViewModel);
            });

            it(@"implements <NSCoding>", ^{
                expect(viewModel).toConformTo(@protocol(NSCoding));

                NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:viewModel];
                expect(encoded).not.toBeNil();

                PROViewModel *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];

                // should not encode the model
                expect(decoded.model).toBeNil();

                decoded.model = viewModel.model;
                expect(decoded).toEqual(viewModel);
            });

            it(@"implements <NSCopying>", ^{
                expect(viewModel).toSupportCopying();
            });

            it(@"invokes custom validation methods for -validateAction:", ^{
                expect([^{
                    expect([viewModel validateAction:@selector(someAction:)]).toBeFalsy();
                } copy]).toInvoke(viewModel, @selector(validateSomeAction));

                viewModel.enabled = YES;

                expect([^{
                    expect([viewModel validateAction:@selector(someAction:)]).toBeTruthy();
                } copy]).toInvoke(viewModel, @selector(validateSomeAction));
            });

            it(@"fails to validate actions that don't exist", ^{
                expect([viewModel validateAction:@selector(action:)]).toBeFalsy();
                expect([viewModel validateAction:@selector(action)]).toBeFalsy();
            });
        });
    });

    describe(@"CollectionTestViewModel subclass", ^{
        it(@"has propertyKeys", ^{
            expect([CollectionTestViewModel propertyKeys]).toContain(@"array");
            expect([CollectionTestViewModel propertyKeys]).toContain(@"dictionary");
            expect([CollectionTestViewModel propertyKeys]).toContain(@"orderedSet");
            expect([CollectionTestViewModel propertyKeys]).toContain(@"set");

            expect([CollectionTestViewModel propertyKeys]).not.toContain(@"name");
        });

        it(@"has defaultValuesForKeys", ^{
            expect([[CollectionTestViewModel defaultValuesForKeys] count]).toEqual(1);
        });

        it(@"initializes with default values", ^{
            CollectionTestViewModel *viewModel = [[CollectionTestViewModel alloc] init];
            expect(viewModel).not.toBeNil();

            NSArray *keys = [[CollectionTestViewModel defaultValuesForKeys] allKeys];
            expect([viewModel dictionaryWithValuesForKeys:keys]).toEqual([CollectionTestViewModel defaultValuesForKeys]);
        });
    });

SpecEnd

@implementation TestViewModel
@synthesize name = m_name;
@synthesize date = m_date;
@synthesize enabled = m_enabled;

- (id)init {
    self = [super init];
    if (!self)
        return nil;

    expect(self.initializingFromArchive).toBeFalsy();
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    self = [super initWithDictionary:dictionary];
    if (!self)
        return nil;

    expect(self.initializingFromArchive).toEqual(m_initWithCoderInvoked);
    return self;
}

- (id)initWithModel:(id)model {
    self = [super initWithModel:model];
    if (!self)
        return nil;

    expect(self.initializingFromArchive).toBeFalsy();
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    m_initWithCoderInvoked = YES;
    return [super initWithCoder:coder];
}

- (void)someAction:(id)sender; {
}

- (BOOL)validateSomeAction; {
    return self.enabled;
}

@end

@implementation CollectionTestViewModel
@synthesize array = m_array;
@synthesize dictionary = m_dictionary;
@synthesize orderedSet = m_orderedSet;
@synthesize set = m_set;

+ (NSDictionary *)defaultValuesForKeys {
    return [NSDictionary dictionaryWithObject:[NSArray array] forKey:@"array"];
}
@end

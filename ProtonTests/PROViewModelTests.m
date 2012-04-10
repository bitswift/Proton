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

@property (nonatomic, copy) NSDate *date;
@property (nonatomic, strong) NSMutableArray *model;

// defaults to 'foobar'
@property (nonatomic, copy) NSString *name;

// these should be archived only conditionally
@property (nonatomic, weak) id weakObject;
@property (nonatomic, unsafe_unretained) id unretainedObject;

@property (nonatomic, getter = isEnabled) BOOL enabled;

- (void)someAction:(id)sender;
- (BOOL)validateSomeAction;
@end

SpecBegin(PROViewModel)

    describe(@"base class", ^{
        it(@"has no defaultValuesForKeys", ^{
            expect([PROViewModel defaultValuesForKeys]).toEqual([NSDictionary dictionary]);
        });

        it(@"should not encode its model by default", ^{
            expect([PROViewModel encodingBehaviorForKey:@"model"]).toEqual(PROViewModelEncodingBehaviorNone);
        });
    });

    describe(@"TestViewModel subclass", ^{
        it(@"should not encode its model by default", ^{
            expect([TestViewModel encodingBehaviorForKey:@"model"]).toEqual(PROViewModelEncodingBehaviorNone);
        });

        it(@"should encode retained objects and primitive values by default", ^{
            expect([TestViewModel encodingBehaviorForKey:@"date"]).toEqual(PROViewModelEncodingBehaviorUnconditional);
            expect([TestViewModel encodingBehaviorForKey:@"enabled"]).toEqual(PROViewModelEncodingBehaviorUnconditional);
        });

        it(@"should conditionally encode unretained objects by default", ^{
            expect([TestViewModel encodingBehaviorForKey:@"weakObject"]).toEqual(PROViewModelEncodingBehaviorConditional);
            expect([TestViewModel encodingBehaviorForKey:@"unretainedObject"]).toEqual(PROViewModelEncodingBehaviorConditional);
        });

        it(@"initializes", ^{
            TestViewModel *viewModel = [[TestViewModel alloc] init];
            expect(viewModel).not.toBeNil();

            expect(viewModel.model).toBeNil();
            expect(viewModel.name).toEqual(@"foobar");
            expect(viewModel.date).toBeNil();
            expect(viewModel.enabled).toBeFalsy();
            expect(viewModel.initializingFromArchive).toBeFalsy();
        });

        it(@"initializes with a model", ^{
            NSMutableArray *array = [NSMutableArray array];

            TestViewModel *viewModel = [[TestViewModel alloc] initWithModel:array];
            expect(viewModel).not.toBeNil();

            expect(viewModel.model).toEqual(array);
            expect(viewModel.name).toEqual(@"foobar");
            expect(viewModel.date).toBeNil();
            expect(viewModel.enabled).toBeFalsy();
            expect(viewModel.initializingFromArchive).toBeFalsy();
            expect(viewModel.parentViewModel).toBeNil();
            expect(viewModel.rootViewModel).toEqual(viewModel);
        });

        describe(@"with an instance", ^{
            __block TestViewModel *viewModel = nil;

            before(^{
                viewModel = [[TestViewModel alloc] init];
                expect(viewModel).not.toBeNil();
                expect([viewModel valueForKey:@"name"]).toEqual(@"foobar");

                viewModel.model = [NSMutableArray array];
                expect(viewModel.model).not.toBeNil();
            });

            it(@"is equal to same view model data", ^{
                TestViewModel *otherViewModel = [[TestViewModel alloc] initWithModel:viewModel.model];
                expect(viewModel).toEqual(otherViewModel);
            });

            it(@"is not equal to a different view model", ^{
                TestViewModel *otherViewModel = [[TestViewModel alloc] init];
                expect(viewModel).not.toEqual(otherViewModel);

                otherViewModel.model = viewModel.model;
                otherViewModel.name = @"fizzbuzz";
                expect(viewModel).not.toEqual(otherViewModel);
            });

            describe(@"with parent view models", ^{
                __block PROViewModel *parentViewModel;

                before(^{
                    parentViewModel = [[PROViewModel alloc] init];
                    expect(parentViewModel).not.toBeNil();

                    viewModel.parentViewModel = parentViewModel;
                    expect(viewModel.parentViewModel).toEqual(parentViewModel);
                });

                it(@"returns its parentViewModel as its rootViewModel when its parentViewModel has no ancestors", ^{
                    expect(viewModel.rootViewModel).toEqual(parentViewModel);
                });

                it(@"returns its ancestor parentViewModel as its rootViewModel", ^{
                    PROViewModel *grandParentViewModel = [[PROViewModel alloc] init];
                    parentViewModel.parentViewModel = grandParentViewModel;

                    expect(viewModel.rootViewModel).toEqual(grandParentViewModel);
                });
            });

            describe(@"archiving behavior", ^{
                __block id unretainedObject = nil;

                before(^{
                    unretainedObject = [@"foobar" mutableCopy];

                    viewModel.weakObject = unretainedObject;
                    viewModel.unretainedObject = unretainedObject;
                    viewModel.enabled = YES;
                    viewModel.date = [NSDate date];
                });

                it(@"archives retained objects and primitive values by default", ^{
                    expect(viewModel).toConformTo(@protocol(NSCoding));

                    NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:viewModel];
                    expect(encoded).not.toBeNil();

                    TestViewModel *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];

                    expect(decoded.model).toBeNil();
                    expect(decoded.weakObject).toBeNil();
                    expect(decoded.unretainedObject).toBeNil();
                    expect(decoded.enabled).toBeTruthy();
                    expect(decoded.date).toEqual(viewModel.date);

                    decoded.model = viewModel.model;
                    expect(decoded).not.toEqual(viewModel);
                });

                it(@"archives unretained objects conditionally", ^{
                    expect(viewModel).toConformTo(@protocol(NSCoding));

                    NSMutableData *encoded = [NSMutableData data];
                    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:encoded];

                    [archiver encodeObject:unretainedObject forKey:@"unretainedObject"];
                    [archiver encodeObject:viewModel forKey:@"viewModel"];

                    [archiver finishEncoding];
                    expect(encoded.length).toBeGreaterThan(0);

                    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:encoded];
                    TestViewModel *decoded = [unarchiver decodeObjectForKey:@"viewModel"];
                    [unarchiver finishDecoding];

                    expect(decoded.model).toBeNil();
                    expect(decoded.weakObject).toEqual(unretainedObject);
                    expect(decoded.unretainedObject).toEqual(unretainedObject);
                    expect(decoded.enabled).toBeTruthy();
                    expect(decoded.date).toEqual(viewModel.date);

                    decoded.model = viewModel.model;
                    expect(decoded).toEqual(viewModel);
                });
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

SpecEnd

@implementation TestViewModel
@synthesize name = m_name;
@synthesize date = m_date;
@synthesize enabled = m_enabled;
@synthesize weakObject = m_weakObject;
@synthesize unretainedObject = m_unretainedObject;

@dynamic model;

- (id)init {
    self = [super init];
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

+ (NSDictionary *)defaultValuesForKeys {
    return [NSDictionary dictionaryWithObject:@"foobar" forKey:@"name"];
}

@end

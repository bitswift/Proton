//
//  PROModelControllerTransformationLog.m
//  Proton
//
//  Created by Justin Spahr-Summers on 05.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROModelControllerTransformationLog.h"
#import "NSObject+ComparisonAdditions.h"
#import "PROKeyValueCodingMacros.h"
#import "PROModelController.h"
#import "PROModelControllerTransformationLogEntry.h"
#import "SDQueue.h"

@implementation PROModelControllerTransformationLog

#pragma mark Properties

@synthesize modelController = m_modelController;

#pragma mark Initialization

- (id)initWithModelController:(PROModelController *)modelController; {
    NSParameterAssert(modelController != nil);

    self = [self init];
    if (!self)
        return nil;

    m_modelController = modelController;
    return self;
}

#pragma mark Log Entries

- (PROModelControllerTransformationLogEntry *)logEntryWithParentLogEntry:(PROModelControllerTransformationLogEntry *)parentLogEntry; {
    NSParameterAssert(!parentLogEntry || [parentLogEntry isKindOfClass:[PROModelControllerTransformationLogEntry class]]);
    
    return [[PROModelControllerTransformationLogEntry alloc] initWithParentLogEntry:parentLogEntry];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (!self)
        return nil;

    m_modelController = [coder decodeObjectForKey:PROKeyForObject(self, modelController)];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];

    if (self.modelController)
        [coder encodeObject:self.modelController forKey:PROKeyForObject(self, modelController)];
}

#pragma mark NSObject overrides

- (BOOL)isEqual:(PROModelControllerTransformationLog *)log {
    if (![log isKindOfClass:[PROModelControllerTransformationLog class]])
        return NO;

    if (!NSEqualObjects(self.modelController, log.modelController))
        return NO;

    return [super isEqual:log];
}

@end

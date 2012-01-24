//
//  PROMutableModel.m
//  Proton
//
//  Created by Justin Spahr-Summers on 24.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROMutableModel.h"

@implementation PROMutableModel

#pragma mark Properties

@synthesize modelController = m_modelController;

#pragma mark Initialization

- (id)initWithModel:(PROModel *)model; {
    return nil;
}

- (id)initWithModelController:(PROModelController *)modelController; {
    return nil;
}

#pragma mark Saving

- (BOOL)save:(NSError **)error; {
    return NO;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)coder {
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone; {
    return nil;
}

#pragma mark NSMutableCopying

- (id)mutableCopyWithZone:(NSZone *)zone; {
    return nil;
}

#pragma mark NSObject overrides

@end

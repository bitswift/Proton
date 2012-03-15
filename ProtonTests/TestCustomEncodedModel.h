//
//  TestCustomEncodedModel.h
//  Proton
//
//  Created by James Lawton on 3/15/12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <CoreData/CoreData.h>

@class TestModel;

@interface TestCustomEncodedModel : NSManagedObject

@property (nonatomic, assign) int32_t unserialized;
@property (nonatomic, retain) TestModel *model;

@end

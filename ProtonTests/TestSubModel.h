//
//  TestSubModel.h
//  Proton
//
//  Created by Justin Spahr-Summers on 21.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class TestModel;

@interface TestSubModel : NSManagedObject

@property (nonatomic) int32_t age;
@property (nonatomic, retain) TestModel *model;

@end

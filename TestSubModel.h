//
//  TestSubModel.h
//  Proton
//
//  Created by Justin Spahr-Summers on 20.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "TestModel.h"


@interface TestSubModel : TestModel

@property (nonatomic) int32_t age;

@end

//
//  TestModel.h
//  Proton
//
//  Created by Justin Spahr-Summers on 20.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface TestModel : NSManagedObject

@property (nonatomic, retain) NSString * name;

@end

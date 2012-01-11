//
//  Proton.h
//  Proton
//
//  Created by Justin Spahr-Summers on 09.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Proton/DDAbstractDatabaseLogger.h>
#import <Proton/DDASLLogger.h>
#import <Proton/DDFileLogger.h>
#import <Proton/DDLog.h>
#import <Proton/DDTTYLogger.h>

/**
 * The default logging level for Proton and projects linking to it.
 *
 * This logging level is based on the configuration with which Proton was built.
 *
 * Individual files can declare a `static int ddLogLevel` variable, which will
 * override this one.
 */
extern int ddLogLevel;

// disable asynchronous logging in Debug builds by default
#ifdef DEBUG
    #undef LOG_ASYNC_ENABLED
    #define LOG_ASYNC_ENABLED NO
#endif

#import <Proton/EXTNil.h>
#import <Proton/EXTRuntimeExtensions.h>
#import <Proton/EXTSafeCategory.h>
#import <Proton/EXTScope.h>
#import <Proton/Foundation+LocalizationAdditions.h>
#import <Proton/NSArray+HigherOrderAdditions.h>
#import <Proton/NSDictionary+HigherOrderAdditions.h>
#import <Proton/NSDictionary+PROKeyedObjectAdditions.h>
#import <Proton/NSObject+ComparisonAdditions.h>
#import <Proton/NSObject+ErrorAdditions.h>
#import <Proton/NSObject+PROKeyValueObserverAdditions.h>
#import <Proton/NSOrderedSet+HigherOrderAdditions.h>
#import <Proton/NSSet+HigherOrderAdditions.h>
#import <Proton/PROFuture.h>
#import <Proton/PROIndexedTransformation.h>
#import <Proton/PROInsertionTransformation.h>
#import <Proton/PROKeyValueCodingMacros.h>
#import <Proton/PROKeyValueObserver.h>
#import <Proton/PROKeyedObject.h>
#import <Proton/PROKeyedTransformation.h>
#import <Proton/PROModel.h>
#import <Proton/PROModelController.h>
#import <Proton/PROMultipleTransformation.h>
#import <Proton/PROOrderTransformation.h>
#import <Proton/PRORemovalTransformation.h>
#import <Proton/PROTransformation.h>
#import <Proton/PROUniqueIdentifier.h>
#import <Proton/PROUniqueTransformation.h>
#import <Proton/SDQueue.h>

//
//  PRODictionaryModel.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PRODictionaryModel.h>

@interface PRODictionaryModel () {
    // use an ivar so that the dictionaryValue doesn't get counted as a property
    // when invoking +propertyKeys
    //
    // this is created as a mutable dictionary, because it might be modified
    // multiple times during initialization (setting each key), but it will be
    // made immutable afterwards
    NSDictionary *m_dictionaryValue;
}

@end

@implementation PRODictionaryModel

#pragma mark Lifecycle

- (id)initWithDictionary:(NSDictionary *)dictionary; {
    // invoke superclass implementation -- we'll create m_dictionaryValue on
    // demand
    self = [super initWithDictionary:dictionary];
    if (!self)
        return nil;

    if (m_dictionaryValue) {
        // make the mutable dictionary immutable
        m_dictionaryValue = [m_dictionaryValue copy];
    } else {
        // set it up with an empty dictionary so that methods behave as expected
        // (returning NSNull/empty dictionaries instead of nil)
        m_dictionaryValue = [NSDictionary dictionary];
    }

    return self;
}

#pragma mark PROKeyedObject

- (NSDictionary *)dictionaryValue {
    return [m_dictionaryValue copy];
}

#pragma mark NSKeyValueCoding

- (NSDictionary *)dictionaryWithValuesForKeys:(NSArray *)keys {
    return [m_dictionaryValue dictionaryWithValuesForKeys:keys];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    NSLog(@"%s %@: value = %@ key = %@", __func__, self, value, key);

    // this should only be invoked from an initialization method
    if (!m_dictionaryValue)
        m_dictionaryValue = [[NSMutableDictionary alloc] init];

    [(id)m_dictionaryValue setValue:value forKey:key];
}

- (id)valueForKey:(NSString *)key {
    return [m_dictionaryValue valueForKey:key];
}

- (id)valueForKeyPath:(NSString *)keyPath {
    return [m_dictionaryValue valueForKeyPath:keyPath];
}

@end

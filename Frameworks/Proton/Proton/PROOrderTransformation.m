//
//  PROOrderTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 24.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROOrderTransformation.h>
#import <Proton/EXTScope.h>
#import <Proton/NSObject+ComparisonAdditions.h>

@implementation PROOrderTransformation

#pragma mark Properties

@synthesize startIndexes = m_startIndexes;
@synthesize endIndexes = m_endIndexes;

- (PROTransformation *)reverseTransformation; {
    // just flip our index sets around
    return [[[self class] alloc] initWithStartIndexes:self.endIndexes endIndexes:self.startIndexes];
}

#pragma mark Initialization

- (id)init; {
    return [self initWithStartIndexes:nil endIndexes:nil];
}

- (id)initWithStartIndexes:(NSIndexSet *)startIndexes endIndexes:(NSIndexSet *)endIndexes; {
    NSParameterAssert([startIndexes count] == [endIndexes count]);

    self = [super init];
    if (!self)
        return nil;

    // don't save empty index sets -- consider them to be nil instead
    if ([startIndexes count]) {
        m_startIndexes = [startIndexes copy];
        m_endIndexes = [endIndexes copy];
    }

    return self;
}

#pragma mark Transformation

- (id)transform:(id)obj; {
    return [super transform:obj];
}

- (PROTransformationBlock)transformationBlockUsingRewriterBlock:(PROTransformationRewriterBlock)block; {
    PROTransformationBlock baseTransformation = ^(id array){
        // if our index sets are nil (both are or neither are), pass all objects
        // through
        if (!self.startIndexes)
            return array;

        if (![array isKindOfClass:[NSArray class]])
            return nil;

        // if either index set goes out of bounds, return nil
        NSUInteger count = [array count];
        if ([self.startIndexes lastIndex] >= count || [self.endIndexes lastIndex] >= count)
            return nil;

        NSMutableArray *newArray = [[NSMutableArray alloc] initWithCapacity:count];

        [array enumerateObjectsUsingBlock:^(id obj, NSUInteger originalIndex, BOOL *stop){
            // if this index isn't moved,
            if (![self.startIndexes containsIndex:originalIndex]) {
                // add the object into the new array
                [newArray addObject:obj];
            }
        }];

        NSUInteger indexCount = [self.startIndexes count];
        NSAssert(indexCount == [self.endIndexes count], @"%@ should have the same number of start and end indexes", self);

        // we have to copy the indexes into C arrays, since there's no way to
        // retrieve values from them one-by-one
        NSUInteger startIndexes[indexCount];
        [self.startIndexes getIndexes:startIndexes maxCount:indexCount inIndexRange:nil];

        NSUInteger endIndexes[indexCount];
        [self.endIndexes getIndexes:endIndexes maxCount:indexCount inIndexRange:nil];

        // for every index that was moved, insert the objects into the proper
        // place after the fact
        for (NSUInteger setIndex = 0; setIndex < indexCount; ++setIndex) {
            NSUInteger originalIndex = startIndexes[setIndex];
            NSUInteger newIndex = endIndexes[setIndex];

            id obj = [array objectAtIndex:originalIndex];
            [newArray insertObject:obj atIndex:newIndex];
        }

        return [newArray copy];
    };

    return ^(id oldValue){
        id newValue;

        if (block) {
            newValue = block(self, baseTransformation, oldValue);
        } else {
            newValue = baseTransformation(oldValue);
        }

        return newValue;
    };
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    NSIndexSet *startIndexes = [coder decodeObjectForKey:@"startIndexes"];
    NSIndexSet *endIndexes = [coder decodeObjectForKey:@"endIndexes"];

    // if one is nil but the other is not,
    if (!startIndexes != !endIndexes) {
        // the object would fail an assertion
        return nil;
    }

    return [self initWithStartIndexes:startIndexes endIndexes:endIndexes];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    if (self.startIndexes)
        [coder encodeObject:self.startIndexes forKey:@"startIndexes"];

    if (self.endIndexes)
        [coder encodeObject:self.endIndexes forKey:@"endIndexes"];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // this object is immutable
    return self;
}

#pragma mark NSObject overrides

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>{ from = %@, to = %@ }", [self class], (__bridge void *)self, self.startIndexes, self.endIndexes];
}

- (NSUInteger)hash {
    return [self.startIndexes hash] ^ [self.endIndexes hash];
}

- (BOOL)isEqual:(PROOrderTransformation *)transformation {
    if (![transformation isKindOfClass:[PROOrderTransformation class]])
        return NO;

    if (!NSEqualObjects(self.startIndexes, transformation.startIndexes))
        return NO;

    if (!NSEqualObjects(self.endIndexes, transformation.endIndexes))
        return NO;

    return YES;
}

@end

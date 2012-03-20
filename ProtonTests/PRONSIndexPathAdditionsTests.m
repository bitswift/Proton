//
//  PRONSIndexPathAdditionsTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 19.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSIndexPath+TransformationAdditions.h"

SpecBegin(PRONSIndexPathAdditions)
    
    __block NSIndexPath *indexPath;
    __block NSIndexPath *emptyPath;

    before(^{
        emptyPath = [NSIndexPath indexPathWithIndexes:NULL length:0];
        expect(emptyPath).not.toBeNil();

        NSUInteger indexes[] = { 2, 5 };
        indexPath = [NSIndexPath indexPathWithIndexes:indexes length:sizeof(indexes) / sizeof(*indexes)];
        expect(indexPath).not.toBeNil();
    });
    
    it(@"should prepend an index", ^{
        NSIndexPath *newPath = [indexPath indexPathByPrependingIndex:1];
        expect(newPath.length).toEqual(indexPath.length + 1);

        expect([newPath indexAtPosition:0]).toEqual(1);
        expect([newPath indexAtPosition:1]).toEqual([indexPath indexAtPosition:0]);
        expect([newPath indexAtPosition:2]).toEqual([indexPath indexAtPosition:1]);
    });

    it(@"should prepend an index to an empty path", ^{
        NSIndexPath *newPath = [emptyPath indexPathByPrependingIndex:1];
        expect(newPath.length).toEqual(1);

        expect([newPath indexAtPosition:0]).toEqual(1);
    });

    it(@"should remove the first index of a path", ^{
        NSIndexPath *newPath = [indexPath indexPathByRemovingFirstIndex];
        expect(newPath.length).toEqual(indexPath.length - 1);

        expect([newPath indexAtPosition:0]).toEqual([indexPath indexAtPosition:1]);
    });

    it(@"should remove the only index of a path", ^{
        NSIndexPath *newPath = [[indexPath indexPathByRemovingFirstIndex] indexPathByRemovingFirstIndex];
        expect(newPath.length).toEqual(0);
    });

    it(@"should return an empty path if attempting to remove from an empty path", ^{
        expect([emptyPath indexPathByRemovingFirstIndex]).toEqual(emptyPath);
    });

SpecEnd

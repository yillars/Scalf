//
//  AFMJSONValueTransformer.m
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 27/7/14.
//  Copyright (c) 2014 Matthew Cheok. All rights reserved.
//

#import "AFMJSONValueTransformer.h"

@interface AFMJSONValueTransformer ()

@property(nonatomic, strong) NSDictionary *mappingDictionary;

@end

@implementation AFMJSONValueTransformer {
    MCJSONValueTransformerBlock _block;
}

+ (instancetype)valueTransformerWithMappingDictionary:(NSDictionary *)dictionary {
    return [[self alloc] initWithMappingDictionary:dictionary];
}

- (instancetype)initWithMappingDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _mappingDictionary = dictionary;
    }
    return self;
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)value {
    if (_block) {
        return _block(value, _propertyKey, _propertyClass, NO);
    } else
        return self.mappingDictionary[value];
}

+ (instancetype)valueTransformerWithBlock:(MCJSONValueTransformerBlock)block {
    return [[self alloc] initWithTransformerBlock:block];
}

- (instancetype)initWithTransformerBlock:(MCJSONValueTransformerBlock)block {
    self = [super init];
    if (self) {
        _block = [block copy];
    }
    return self;
}

- (id)reverseTransformedValue:(id)value {
    if (_block) {
        return _block(value, _propertyKey, _propertyClass, YES);
    } else
        return [[self.mappingDictionary allKeysForObject:value] firstObject];
}

@end

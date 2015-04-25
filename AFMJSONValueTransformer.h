//
//  AFMJSONValueTransformer.h
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 27/7/14.
//  Copyright (c) 2014 Matthew Cheok. All rights reserved.
//  Updated by Ali Kıran on 26/03/2015
//

#import <Foundation/Foundation.h>

typedef id(^MCJSONValueTransformerBlock)(id value, NSString *propertyKey, Class propertyClass, BOOL reversed);

@interface AFMJSONValueTransformer : NSValueTransformer

@property(nonatomic, strong) Class propertyClass;
@property(nonatomic, copy) NSString *propertyKey;

+ (instancetype)valueTransformerWithMappingDictionary:(NSDictionary *)dictionary;

+ (instancetype)valueTransformerWithBlock:(MCJSONValueTransformerBlock)block;

- (instancetype)initWithTransformerBlock:(MCJSONValueTransformerBlock)block;

- (instancetype)initWithMappingDictionary:(NSDictionary *)dictionary;


@end

//
//  RLMObject+JSON.h
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 27/7/14.
//  Copyright (c) 2014 Matthew Cheok. All rights reserved.
//

#import <Realm/Realm.h>
#import "AFMJSONDateTransformer.h"
#import "AFMJSONValueTransformer.h"

@interface RLMObject (JSON)

+ (NSArray *)createWithJSONArray:(NSArray *)array;

+ (NSArray *)createInRealm:(RLMRealm *)realm withJSONArray:(NSArray *)array;

+ (NSArray *)createInRealm:(RLMRealm *)realm withJSONArray:(NSArray *)array returnNewObjectsOnly:(BOOL)newOnly;

+ (instancetype)createWithJSONDictionary:(NSMutableDictionary *)dictionary;

+ (instancetype)createInRealm:(RLMRealm *)realm withJSONDictionary:(NSMutableDictionary *)dictionary;

- (instancetype)initWithJSONDictionary:(NSDictionary *)dictionary;

    - ( NSDictionary * )JSONMutableDictionary:( BOOL )useCamel;
    - ( NSDictionary * )JSONDictionary;
    - ( NSDictionary * )JSONDictionary:( BOOL )useCamel;

- (id)primaryKeyValue;

+ (id)primaryKeyValueFromJSONDictionary:(NSMutableDictionary **)dictionary;


+ (instancetype)mc_createOrUpdateInRealm:(RLMRealm *)realm withJSONDictionary:(NSMutableDictionary *)dictionary;

- (void)performInTransaction:(void (^)())transaction;

- (void)removeFromRealm;

@end

@interface RLMArray (SWAdditions)

- (NSArray *)NSArray;

- (NSArray *)JSONArray;

@end

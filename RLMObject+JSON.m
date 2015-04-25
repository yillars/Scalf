//  RLMObject+JSON.m
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 27/7/14.
//  Copyright (c) 2014 Matthew Cheok. All rights reserved.
//  Updated by Ali Kıran on 26/03/2015
//

#import "RLMObject+JSON.h"
#import "NSObject+Mapping.h"
#import <objc/runtime.h>

static id MCValueFromInvocation(id object, SEL selector) {
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:selector]];
    invocation.target   = object;
    invocation.selector = selector;
    [invocation invoke];

    __unsafe_unretained id result = nil;
    [invocation getReturnValue:&result];

    return result;
}

static NSString *MCTypeStringFromPropertyKey(Class class, NSString *key) {
    const objc_property_t property = class_getProperty(class, [key UTF8String]);
    if (!property) {
        [NSException raise:NSInternalInconsistencyException format:@"Class %@ does not have property %@", class, key];
    }
    const char *type = property_getAttributes(property);
    return [NSString stringWithUTF8String:type];
}

@interface NSString (MCJSON)

- (NSString *)snakeToCamelCase;

- (NSString *)camelToSnakeCase;

@end

@implementation RLMObject (JSON)

+ (NSArray *)createWithJSONArray:(NSArray *)array {
    return [self createInRealm:[RLMRealm defaultRealm] withJSONArray:array returnNewObjectsOnly:NO];
}

+ (NSArray *)createInRealm:(RLMRealm *)realm withJSONArray:(NSArray *)array {
    return [self createInRealm:realm withJSONArray:array returnNewObjectsOnly:NO];
}

+ (NSArray *)createInRealm:(RLMRealm *)realm withJSONArray:(NSArray *)array returnNewObjectsOnly:(BOOL)newOnly {
    NSMutableArray *result = [NSMutableArray array];

    for (NSMutableDictionary *data in array) {
        NSMutableDictionary *dict = data.mutableCopy;
        if (newOnly) {
            id   primaryKeyValue = [self primaryKeyValueFromJSONDictionary:&dict];
            BOOL exists          = primaryKeyValue && [self objectForPrimaryKey:primaryKeyValue] != nil;

            id object = [self mc_createOrUpdateInRealm:realm withJSONDictionary:dict];
            if (!exists) {
                [result addObject:object];
            }
        } else {
            id object = [self mc_createOrUpdateInRealm:realm withJSONDictionary:dict];
            [result addObject:object];
        }
    }

    return [result copy];
}

+ (instancetype)createWithJSONDictionary:(NSMutableDictionary *)dictionary {
    id object = [self mc_createOrUpdateInRealm:[RLMRealm defaultRealm] withJSONDictionary:dictionary];

    return object;
}

+ (instancetype)createInRealm:(RLMRealm *)realm withJSONDictionary:(NSMutableDictionary *)dictionary {
    id object = [self mc_createOrUpdateInRealm:realm withJSONDictionary:dictionary];

    return object;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        [self mc_setValuesFromJSONDictionary:dictionary inRealm:nil update:NO];
    }
    return self;
}

- (NSDictionary *)JSONDictionary {
    return [self mc_createJSONDictionary];
}

- (id)primaryKeyValue {
    NSString *primaryKey = [[self class] primaryKey];
    NSAssert(primaryKey, @"No primary key on class %@", [self description]);

    return [self valueForKeyPath:primaryKey];
}

+ (id)primaryKeyValueFromJSONDictionary:(NSMutableDictionary **)dictionary {
    NSCAssert(dictionary, @"must be dictionary");
    NSCAssert([*dictionary isKindOfClass:[NSDictionary class]], @"dictionary must be mutable");

    NSString *primaryKey = [[self class] primaryKey];
    if (!primaryKey) {
        return nil;
    }

    NSDictionary *inboundMapping = [self mc_inboundMapping];
    NSString     *primaryKeyPath = [[inboundMapping allKeysForObject:primaryKey] firstObject];

    if (!primaryKeyPath)primaryKeyPath = primaryKey;
    id primaryKeyValue = [*dictionary valueForKeyPath:primaryKeyPath];

    NSValueTransformer *transformer = [self mc_transformerForPropertyKey:primaryKey];
    if (transformer) {
        primaryKeyValue = [transformer transformedValue:*dictionary];
    }

    return primaryKeyValue;
}

- (void)performInTransaction:(void (^)())transaction {
    NSAssert(transaction != nil, @"No transaction block provided");
    if (self.realm) {
        [self.realm transactionWithBlock:transaction];
    }
    else {
        transaction();
    }
}

- (void)removeFromRealm {
    [self.realm deleteObject:self];
}

+ (instancetype)mc_createFromJSONDictionary:(NSDictionary *)dictionary {
    id object = [[self alloc] init];
    [object mc_setValuesFromJSONDictionary:dictionary inRealm:nil update:NO];
    return object;
}

+ (instancetype)mc_createOrUpdateInRealm:(RLMRealm *)realm withJSONDictionary:(NSMutableDictionary *)dictionary {
    if (!dictionary || [dictionary isEqual:[NSNull null]]) {
        return nil;
    }

    NSCAssert([dictionary isKindOfClass:[NSMutableDictionary class]], @"dictionary must be mutable");

    dictionary                = [dictionary mutableCopy];

    RLMObject *object;
    id        primaryKeyValue = [self primaryKeyValueFromJSONDictionary:&dictionary];

    if (primaryKeyValue) {
        object = [self objectForPrimaryKey:primaryKeyValue];
    }

    if (object) {
        [object mc_setValuesFromJSONDictionary:dictionary inRealm:realm update:YES];
    }
    else {
        object = [[self alloc] init];

        [object mc_setValuesFromJSONDictionary:dictionary inRealm:realm update:NO];
        [realm addOrUpdateObject:object];
    }

    return object;
}

- (void)mc_setValuesFromJSONDictionary:(NSDictionary *)dictionary inRealm:(RLMRealm *)realm update:(BOOL)update {
    NSDictionary        *class_mapping = [[self class] mc_inboundMapping].mutableCopy;
    NSMutableDictionary *mapping       = [NSMutableDictionary new];
    NSArray             *data_keys     = dictionary.allKeys;

    for (NSString *key in class_mapping) {
        if ([data_keys containsObject:key]) {
            mapping[key] = class_mapping[key];
        }
    }

    NSMutableSet *class_set   = [[NSMutableSet alloc] initWithArray:class_mapping.allKeys];
    NSMutableSet *dict_set    = [[NSMutableSet alloc] initWithArray:dictionary.allKeys];
    NSSet        *mapping_set = [[NSSet alloc] initWithArray:mapping.allKeys];

    [class_set minusSet:mapping_set];
    [dict_set minusSet:mapping_set];

    Class    klass       = NSClassFromString(self.objectSchema.className);
    NSString *primaryKey = [klass primaryKey];

    if (update) {
        [mapping removeObjectForKey:primaryKey];
    } else {
        NSCAssert(primaryKey, @"object must define one of primary key");
        if (![mapping allKeysForObject:primaryKey].count) {
            mapping[primaryKey] = primaryKey;
        }
    }

    id primaryValue = self.primaryKeyValue;

    //printf("\n-> Property Inspection on %s -\n", self.objectSchema.className.UTF8String);
//    NSLog(@"missing class fields on json %@", class_set);
//    NSLog(@"missing json fields on class %@", dict_set);
    //printf("------\n\n");

    for (NSString *dictionaryKeyPath in mapping) {
        NSString *objectKeyPath         = mapping[dictionaryKeyPath];

        id                 value;
        NSValueTransformer *transformer = [[self class] mc_transformerForPropertyKey:objectKeyPath];

        if (transformer) {
            value = [transformer transformedValue:dictionary];
        } else {
            value = [dictionary valueForKeyPath:dictionaryKeyPath];
        }
        if (!value) {
            value = [[self.class defaultPropertyValues] valueForKeyPath:objectKeyPath];
        }

        Class modelClass    = [[self class] mc_normalizedClass];
        Class propertyClass = [modelClass mc_classForPropertyKey:objectKeyPath];

        if (value && value != [NSNull null]) {
            if ([propertyClass isSubclassOfClass:[RLMObject class]]) {
                if (realm) {
                    value = [value mutableCopy];
                    NSCAssert([value isKindOfClass:[NSDictionary class]], @"value must be dictionary");
                    NSCAssert([propertyClass primaryKey], @"property class must have primary key");
                    //if id transformer evaluate it earlier
                    NSValueTransformer *prop_id_transform = [propertyClass mc_transformerForPropertyKey:[propertyClass primaryKey]];

                    if (prop_id_transform)
                        value[[propertyClass primaryKey]] = [prop_id_transform transformedValue:value];

                    NSString *message = [NSString stringWithFormat:@"Primary key value not found in json! [Property Class %@, property %@]", NSStringFromClass(propertyClass), [propertyClass primaryKey]];
                    NSCAssert([((NSDictionary *) value) valueForKey:[propertyClass primaryKey]], message);

                    value = [propertyClass mc_createOrUpdateInRealm:realm withJSONDictionary:value];
                }
                else {
                    value = [propertyClass mc_createFromJSONDictionary:value];
                }
            }
            else if ([propertyClass isSubclassOfClass:[RLMArray class]]) {
                RLMArray *array = [self valueForKeyPath:objectKeyPath];
                [array removeAllObjects];

                Class                    itemClass = NSClassFromString(array.objectClassName);
                for (NSMutableDictionary *itemDictionary in(NSArray *) value) {
                    if (realm) {
                        id item = [itemClass mc_createOrUpdateInRealm:realm withJSONDictionary:itemDictionary];
                        [array addObject:item];
                    }
                    else {
                        id item = [itemClass mc_createFromJSONDictionary:value];
                        [array addObject:item];
                    }
                }
                continue;
            }
        }

        if (value == [NSNull null]) {
            if ([propertyClass isSubclassOfClass:[NSDate class]]) {
                value = [NSDate distantPast];
            }
            else if ([propertyClass isSubclassOfClass:[NSString class]]) {
                value = @"";
            } else if ([propertyClass isSubclassOfClass:[RLMArray class]]) {
                value = nil;
            } else if ([propertyClass isSubclassOfClass:[RLMObject class]]) {
                value = nil;
            }
            else {
                value = nil;
            }
        }

        [self setValue:value forKeyPath:objectKeyPath];
    }
}

- (id)mc_createJSONDictionary {
    NSMutableDictionary *result  = [NSMutableDictionary dictionary];
    NSDictionary        *mapping = [[self class] mc_outboundMapping];

    for (NSString *objectKeyPath in mapping) {
        NSString *dictionaryKeyPath = mapping[objectKeyPath];

        id value = [self valueForKeyPath:objectKeyPath];
        if ([value isKindOfClass:[NSString class]]) {
            value = ((NSString *) value).length ? value : nil;
        }

        if ([value isKindOfClass:[RLMArray class]]) {
            value = ((RLMArray *) value).count ? value : nil;
        }

        if (value) {
            NSLog(@"");
            Class modelClass    = [[self class] mc_normalizedClass];
            Class propertyClass = [modelClass mc_classForPropertyKey:objectKeyPath];

            if ([propertyClass isSubclassOfClass:[RLMObject class]]) {
                value = [value mc_createJSONDictionary];
                NSLog(@"");
            }
            else if ([propertyClass isSubclassOfClass:[RLMArray class]]) {
                NSMutableArray *array = [NSMutableArray array];
                for (id        item in(RLMArray *) value) {
                    [array addObject:[item mc_createJSONDictionary]];
                }
                value = array.count ? [array copy] : nil;
            }
            else {
                NSValueTransformer *transformer = [modelClass mc_transformerForPropertyKey:objectKeyPath];

                if (value && transformer) {
                    value = [transformer reverseTransformedValue:value];
                }
            }

            if ([dictionaryKeyPath isEqualToString:@"self"]) {
                return value;
            }

            NSArray       *keyPathComponents = [dictionaryKeyPath componentsSeparatedByString:@"."];
            id            currentDictionary  = result;
            for (NSString *component in keyPathComponents) {
                if ([currentDictionary valueForKey:component] == nil) {
                    [currentDictionary setValue:[NSMutableDictionary dictionary] forKey:component.snakeToCamelCase];
                }
                currentDictionary = [currentDictionary valueForKey:component];
            }

            if ([value isKindOfClass:[NSDictionary class]]) {
                value = [value allKeys].count ? value : nil;
            }

            if (value)
                [result setValue:value forKeyPath:dictionaryKeyPath.snakeToCamelCase];
        }
    }

    return [result copy];
}

#pragma mark - Properties

+ (NSDictionary *)mc_defaultInboundMapping {
    unsigned        count       = 0;
    objc_property_t *properties = class_copyPropertyList(self, &count);

    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (unsigned       i       = 0; i < count; i++) {
        objc_property_t property = properties[i];
        NSString        *name    = [NSString stringWithUTF8String:property_getName(property)];
        result[[name camelToSnakeCase]] = name;
        result[name]                    = name;
    }

    return [result copy];
}

+ (NSDictionary *)mc_defaultOutboundMapping {
    unsigned        count       = 0;
    objc_property_t *properties = class_copyPropertyList(self, &count);

    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (unsigned       i       = 0; i < count; i++) {
        objc_property_t property = properties[i];
        NSString        *name    = [NSString stringWithUTF8String:property_getName(property)];
        result[name] = [name camelToSnakeCase];
    }

    return [result copy];
}

#pragma mark - Convenience Methods


+ (NSDictionary *)mc_inboundMapping {
    Class objectClass = [self mc_normalizedClass];

    NSCAssert(objectClass, @"");

    static NSMutableDictionary *mappingForClassName = nil;
    if (!mappingForClassName) {
        mappingForClassName = [NSMutableDictionary dictionary];
    }

    NSDictionary *mapping = mappingForClassName[[objectClass description]];
    if (!mapping) {
        SEL selector = NSSelectorFromString(@"JSONInboundMappingDictionary");
        if ([objectClass respondsToSelector:selector]) {
            mapping                        = MCValueFromInvocation(objectClass, selector);
            NSMutableDictionary *m_mapping = [objectClass mc_defaultInboundMapping].mutableCopy;
            [mapping enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                m_mapping[key] = obj;
            }];

            mapping = m_mapping;

            NSCAssert(mapping, @"");
        }
        else {
            mapping = [objectClass mc_defaultInboundMapping];
            NSCAssert(mapping, @"");
        }

        mappingForClassName[[objectClass description]] = mapping;
    }

    return mapping;
}

+ (NSDictionary *)mc_outboundMapping {
    Class                      objectClass          = [self mc_normalizedClass];
    static NSMutableDictionary *mappingForClassName = nil;
    if (!mappingForClassName) {
        mappingForClassName = [NSMutableDictionary dictionary];
    }

    NSDictionary *mapping = mappingForClassName[[objectClass description]];
    if (!mapping) {
        SEL selector = NSSelectorFromString(@"JSONOutboundMappingDictionary");
        if ([objectClass respondsToSelector:selector]) {
            mapping = MCValueFromInvocation(objectClass, selector);
        }
        else {
            mapping = [objectClass mc_defaultOutboundMapping];
        }
        mappingForClassName[[objectClass description]] = mapping;
    }
    return mapping;
}

+ (Class)mc_classForPropertyKey:(NSString *)key {
    NSString *attributes = MCTypeStringFromPropertyKey(self, key);
    if ([attributes hasPrefix:@"T@"]) {
        static NSCharacterSet *set = nil;
        if (!set) {
            set = [NSCharacterSet characterSetWithCharactersInString:@"\"<"];
        }

        NSString  *string;
        NSScanner *scanner         = [NSScanner scannerWithString:attributes];
        scanner.charactersToBeSkipped = set;
        [scanner scanUpToCharactersFromSet:set intoString:NULL];
        [scanner scanUpToCharactersFromSet:set intoString:&string];
        return NSClassFromString(string);
    }
    return nil;
}

+ (NSValueTransformer *)mc_transformerForPropertyKey:(NSString *)key {
    Class modelClass    = [[self class] mc_normalizedClass];
    Class propertyClass = [modelClass mc_classForPropertyKey:key];
    SEL   selector      = NSSelectorFromString([key stringByAppendingString:@"JSONTransformer"]);

    NSValueTransformer *transformer = nil;
    if ([self respondsToSelector:selector]) {
        transformer = MCValueFromInvocation(self, selector);
        if ([transformer isKindOfClass:[AFMJSONValueTransformer class]]) {
            ((AFMJSONValueTransformer *) transformer).propertyClass = propertyClass;
            ((AFMJSONValueTransformer *) transformer).propertyKey   = key;
        }
    }
    else if ([propertyClass isSubclassOfClass:[NSDate class]]) {
        transformer = [NSValueTransformer valueTransformerForName:MCJSONDateTimeTransformerName];
        ((AFMJSONDateTransformer *) transformer).propertyClass = propertyClass;
        ((AFMJSONDateTransformer *) transformer).propertyKey   = key;
    }

    return transformer;
}

@end

@implementation NSString (MCJSON)

- (NSString *)snakeToCamelCase {
    NSScanner      *scanner       = [NSScanner scannerWithString:self];
    NSCharacterSet *underscoreSet = [NSCharacterSet characterSetWithCharactersInString:@"_"];
    scanner.charactersToBeSkipped = underscoreSet;

    NSMutableString *result = [NSMutableString string];
    NSString        *buffer = nil;

    while (![scanner isAtEnd]) {
        BOOL atStartPosition = scanner.scanLocation == 0;
        [scanner scanUpToCharactersFromSet:underscoreSet intoString:&buffer];
        [result appendString:atStartPosition ? buffer : [buffer capitalizedString]];
    }

    return result;
}

- (NSString *)camelToSnakeCase {
    NSScanner      *scanner      = [NSScanner scannerWithString:self];
    NSCharacterSet *uppercaseSet = [NSCharacterSet uppercaseLetterCharacterSet];
    scanner.charactersToBeSkipped = uppercaseSet;

    NSMutableString *result = [NSMutableString string];
    NSString        *buffer = nil;

    while (![scanner isAtEnd]) {
        [scanner scanUpToCharactersFromSet:uppercaseSet intoString:&buffer];
        [result appendString:[buffer lowercaseString]];

        if (![scanner isAtEnd]) {
            [result appendString:@"_"];
            [result appendString:[[self substringWithRange:NSMakeRange(scanner.scanLocation, 1)] lowercaseString]];
        }
    }

    return result;
}

@end

@implementation RLMArray (SWAdditions)

- (NSArray *)NSArray {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:self.count];
    for (id        object in self) {
        [array addObject:object];
    }
    return [array copy];
}

- (NSArray *)JSONArray {
    NSMutableArray *array = [NSMutableArray array];
    for (RLMObject *object in self) {
        [array addObject:[object JSONDictionary]];
    }
    return [array copy];
}

@end

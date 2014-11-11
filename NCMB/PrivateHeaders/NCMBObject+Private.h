//
//  NCMBObject+Private.h
//  NIFTY Cloud mobile backend
//
//  Created by NIFTY Corporation on 2014/10/08.
//  Copyright (c) 2014年 NIFTY Corporation. All rights reserved.
//

#import "NCMBObject.h"

@interface NCMBObject (Private)

- (NSDictionary*)getLocalData;

+ (NCMBObject *)objectWithClassName:(NSString*)className data:(NSDictionary *)attrs;

/**
 指定されたクラス名とobjectIdでNCMBObjectのインスタンスを作成する
 @param className 指定するクラス名
 @param objectId 指定するオブジェクトID
 */
+ (NCMBObject*)objectWithClassName:(NSString*)className objectId:(NSString*)objectId;

/**
 通信前に履歴の取り出しと、次のOperationを保存するDictionaryをキューにセットする
 @return currentOperations オブジェクトの操作履歴
 */
-(NSMutableDictionary *)beforeConnection;

/**
 オブジェクト更新後に操作履歴とestimatedDataを同期する
 */
-(void)afterSave:(NSDictionary*)response operations:(NSMutableDictionary*)operations;

/**
 fetchを実行したあとにプロパティとestimatedDataの更新を行う
 @param response レスポンスのDicitonary
 @param isRefresh リフレッシュ実行フラグ
 */
- (void)afterFetch:(NSMutableDictionary*)response isRefresh:(BOOL)isRefresh;

/**
 ローカルオブジェクトをリセットする
 */
- (void)afterDelete;

/**
 キューから最後(前回)の履歴データの取り出し
 @return 一番最後の操作履歴
 */
- (NSMutableDictionary *)currentOperations;

/**
 渡された履歴操作を実行する
 */
-(void)performOperation:(NSString *)key byOperation:(id)operation;

/**
 JSONオブジェクトをNCMBObjectに変換する
 @param jsonData JSON形式のデータ
 */
- (id)convertToNCMBObjectFromJSON:(id)jsonData;

/**
 mobile backendにオブジェクトを保存する。非同期通信を行う。
 @param block 通信後に実行されるblock。引数にBOOL succeeded, NSError *errorを持つ。
 */
-(NSMutableDictionary *)convertToJSONDicFromOperation:(NSMutableDictionary*)operations;

/**
 NCMBObjectをJSONに変換する
 @param obj NCMBオブジェクト
 */
- (id)convertToJSONFromNCMBObject:(id)obj;

/**
 リクエストURLを受け取ってdeleteを実行する
 @param url リクエストURL
 @param error エラーを保持するポインタ
 */
- (BOOL)delete:(NSString *)url error:(NSError *__autoreleasing *)error;

/**
 リクエストURLを受け取ってdeleteを実行する。非同期通信を行う。
 @param url リクエストURL
 @param block
 */
- (void)deleteInBackgroundWithBlock:(NSString *)url block:(NCMBDeleteResultBlock)userBlock;

/**
 リクエストURLを受け取ってmobile backendにオブジェクトを保存する。非同期通信を行う。
 @param url リクエストURL
 @param block 通信後に実行されるblock。引数にBOOL succeeded, NSError *errorを持つ。
 */
- (void)saveInBackgroundWithBlock:(NSString *)url block:(NCMBSaveResultBlock)userBlock;

/**
 リクエストURLを受け取ってsave処理を実行する
 @param url リクエストURL
 @param エラーを保持するポインタ
 @return 通信が行われたかを真偽値で返却する
 */
- (BOOL)save:(NSString*)url error:(NSError **)error;

/**
 リクエストURLを受け取ってfetchを実行する。非同期通信を行う。
 @param url リクエストURL
 @param userBlock 通信後に実行されるblock。引数にNSError *errorを持つ。
 */
- (void)fetchInBackgroundWithBlock:(NSString *)url block:(NCMBFetchResultBlock)userBlock isRefresh:(BOOL)isRefresh;

/**
 リクエストURLを受け取ってfetchを実行する。
 @param url リクエストURL
 @param error エラーを保持するポインタ
 @return 通信が成功した場合にはYESを返す
 */
- (BOOL)fetch:(NSString*)url error:(NSError **)error isRefresh:(BOOL)isRefresh;

/**
 NCMB形式の日付型NSDateFormatterオブジェクトを返す
 */
-(NSDateFormatter*)createNCMBDateFormatter;

/**
 mobile backendからエラーが返ってきたときに最新の操作履歴と通信中の操作履歴をマージする
 @param operations 最新の操作履歴
 */
- (void)mergePreviousOperation:(NSMutableDictionary*)operations;

//TODO:サブクラスヘッダーに書く
+ (id)object;


@end
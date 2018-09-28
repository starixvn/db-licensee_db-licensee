/*<info serverAlias="DBCUST-SiteConfig" executers="Dot_Admin_Portal" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Portal_UserFuncPermission_InsertOrUpdate] @UserSEQ        INT,
                                                                 @FunctionKey    VARCHAR(50),
                                                                 @SiteName       VARCHAR(50),
                                                                 @SystemType     TINYINT,
                                                                 @SubFunctionKey VARCHAR(1000) = NULL,
                                                                 @Status         INT
AS
/*
	 Creator: 20170630@Alex
	 Task:  Insert Or Update User function permissions
	 Database: DBCUST.SITECONFIG
	 
	 Revisions:
		- 20170630@Alex: Create SP
*/
     BEGIN
         SET NOCOUNT ON;
         DECLARE @IsAllowed BIT= 0;
         IF @Status = 0
             BEGIN
                 DELETE FROM dbo.UserFuncPermission
                 WHERE UserSEQ = @UserSEQ
                       AND FunctionKey = @FunctionKey
                       AND SiteName = @SiteName
                       AND SystemType = @SystemType;
         END;
             ELSE
             BEGIN
                 SELECT TOP 1 @IsAllowed = CASE
                                               WHEN @Status = 1
                                               THEN 1
                                               ELSE 0
                                           END;
                 IF EXISTS
                 (
                     SELECT FunctionKey
                     FROM dbo.UserFuncPermission WITH (NOLOCK)
                     WHERE UserSEQ = @UserSEQ
                           AND FunctionKey = @FunctionKey
                           AND SiteName = @SiteName
                           AND SystemType = @SystemType
                 )
                     BEGIN
                         UPDATE dbo.UserFuncPermission
                           SET
                               IsAllow = @IsAllowed,
                               SubFunctionKeys = @SubFunctionKey
                         WHERE UserSEQ = @UserSEQ
                               AND FunctionKey = @FunctionKey
                               AND SiteName = @SiteName
                               AND SystemType = @SystemType;
                 END;
                     ELSE
                     BEGIN
                         INSERT INTO dbo.UserFuncPermission
                         (UserSEQ,
                          FunctionKey,
                          SiteName,
                          SystemType,
                          SubFunctionKeys,
                          IsAllow
                         )
                         VALUES
                         (@UserSEQ,
                          @FunctionKey,
                          @SiteName,
                          @SystemType,
                          @SubFunctionKey,
                          @IsAllowed
                         );
                 END;
         END;
     END;
GO

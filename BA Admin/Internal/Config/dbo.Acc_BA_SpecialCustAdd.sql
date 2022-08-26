/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/ 
ALTER PROCEDURE [dbo].[Acc_BA_SpecialCustAdd]
(
	@LicenseeID  INT =NULL,
	@str VARCHAR(MAX),
	@ugroup VARCHAR(3),
	@modifyby INT,
	@IP VARCHAR(50),
	@ErrCode	INT = 0 OUTPUT,		
	@ErrMsg		varchar(1000)='' OUTPUT 
)
AS
/*
	Created: Jim
	Date: 5-03-2012
	Task : Replace hardcode member spread by web application
	DB: DBCUST/bodb_Licensee
	Original:

	Revisions:
		- 20130123@Daniel: Change link server alias
		- 20131113@Winnie: Change DBTXN.bodb02 to DBTXN.CustDB
		- 20150606@Kathy: Change link server DBTXN.CustDB to DBCust.CustDB [Redmine:#36216]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20220301@Eden: Deposit - Sportsbook - Revise customer settings [Redmine: #167898] 
	Param's Explanation:
	 
*/
BEGIN
	DECLARE @CustomerList   AS TABLE (ID int IDENTITY(1,1),strvalue char(50))
	DECLARE @CustomerID   AS TABLE (ID int IDENTITY(1,1),CustID INT, Username VARCHAR (100) )

	DECLARE @UserName VARCHAR (100)
	DECLARE @ugroup_old VARCHAR(3)
	DECLARE @MaxID INT,@CustID INT ,@i INT ,@isBA BIT,@ERROR INT ,@mess VARCHAR(MAX)

	INSERT INTO @CustomerList(strvalue) 
	SELECT RTRIM(LTRIM(value)) FROM string_split(@str,',')	WHERE value <> ''				

	INSERT INTO @CustomerID (CustID,Username) 
	SELECT CustID,username FROM CustDB.dbo.customer WITH (NOLOCK) WHERE username IN (SELECT RTRIM(LTRIM(strvalue)) FROM @CustomerList)

	SELECT @MaxID=COUNT(1) FROM @CustomerID 

	SET @i=1 
	SET @ERROR=0
	SET @mess	=''

	WHILE (@i<=@MaxID)
		BEGIN
			DECLARE @grouphk VARCHAR(3)
			SET @grouphk=''
			SELECT @CustID=CustID,@UserName=Username FROM @CustomerID WHERE ID=@i
			 -- Get old ugroup from LicenseeSpecialCust
			IF  EXISTS (SELECT 1 FROM LicenseeSpecialCust  WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND CustID=@CustiD)
			BEGIN
				SELECT @ugroup_old=ugroup  FROM LicenseeSpecialCust WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND CustID=@CustID
				IF (@ugroup_old<>@ugroup)	
				BEGIN
					IF (LEFT(@ugroup_old,2)='hk')
						SELECT @grouphk='hk'+@ugroup
					ELSE 
						SELECT @grouphk=@ugroup
					UPDATE LicenseeSpecialCust WITH (ROWLOCK,UPDLOCK)
					SET ugroup=@grouphk,  modifyby=@modifyby , modifydate=getdate()
					WHERE  LicenseeID=@LicenseeID AND CustID=@CustID 
					-- Write log
					IF EXISTS(SELECT 1 FROM LicenseeSpecialCust WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND CustID=@CustID AND ugroup=@grouphk)
					BEGIN
						EXEC Lrf_WriteLog_UserLog_LicenseeSpecialCust_Wrapper
							@LicenseeID = @LicenseeID,
							@CustID = @CustID,
							@ugroup = @grouphk,
							@ugroup_old = @ugroup_old,
							@UserId = @modifyby, 
							@IP = @IP,
							@ActionType = 'Update'
					END
				END
				
			END				
			ELSE 	-- -- Get old ugroup from Customer
			BEGIN
				SELECT @ugroup_old=ugroup FROM CustDB.dbo.Customer WITH (NOLOCK) 
				WHERE CustID=@CustID
				BEGIN
					IF (LEFT(@ugroup_old,2)='hk')
						SELECT @grouphk='hk'+@ugroup
					ELSE
						SELECT @grouphk=@ugroup
					INSERT INTO LicenseeSpecialCust(LicenseeID,CustID,ugroup,ugroup_old,modifyby,modifydate) 
					VALUES (@LicenseeID,@CustID,@grouphk,@ugroup_old,@modifyby,getdate())
					-- Write log
					IF EXISTS(SELECT 1 FROM LicenseeSpecialCust  WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND CustID=@CustID AND ugroup=@grouphk AND ugroup_old=@ugroup_old )
					BEGIN
						EXEC Lrf_WriteLog_UserLog_LicenseeSpecialCust_Wrapper
							@LicenseeID = @LicenseeID,
							@CustID = @CustID,
							@ugroup = @grouphk,
							@ugroup_old = @ugroup_old,
							@UserId = @modifyby, 
							@IP = @IP,
							@ActionType = 'AddNew'
					END
				END		
			END 	
				-- Check customer is BA
			IF EXISTS (SELECT 1 FROM LicenseeBAHistory  WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND CustID=@CustID AND Status='Running')
			BEGIN
				SELECT @isBA=1 
				SELECT @ErrMsg='',@ErrCode=0

				-- Get ugroup from LicenseeBAHistory
				SELECT @ugroup_old = ugroup
				FROM LicenseeBAHistory WITH (NOLOCK)
				WHERE LicenseeID=@LicenseeID AND CustID=@CustID AND Status='Running'
				-- Save ugroup from LicenseeBAHistory to ugroup_old
				UPDATE LicenseeSpecialCust WITH (ROWLOCK,UPDLOCK)
				SET ugroup_old =  @ugroup_old
				WHERE  LicenseeID=@LicenseeID AND CustID=@CustID 

				-- Update ugroup to LicenseeBAHistory table
				UPDATE LicenseeBAHistory WITH (ROWLOCK,UPDLOCK)
				SET Ugroup = @grouphk 
				WHERE LicenseeID=@LicenseeID AND CustID=@CustID AND Status='Running'
				-- Update comm for BA member
				EXEC CustDB.dbo.Lrf_CustomerUpdMemberBAComm
					@LicenseeID=@LicenseeID,
					@custid=@CustID,
					@ModifyBy=@Modifyby,
					@IsBA=@isBA,
					@IP=@IP,
					@IsAdmin=1,
					@ErrCode = @ErrCode OUTPUT,
					@ErrMsg = @ErrMsg OUTPUT
				IF 	@ErrCode <> 0
				BEGIN
					SELECT @ERROR = 1
					SELECT @mess = @mess + ' ' + @UserName
				END
			END
			ELSE -- Normal member
			BEGIN		
				SET @ErrCode = 0
		
				-- Update ugroup to Customer table
				EXEC CustDB.dbo.Acc_BA_SpecialCustUpdUgroup
					@custid = @CustID,
					@ugroup = @grouphk,
					@userid = @modifyby,
					@IP = @IP,
					@ErrCode = @ErrCode OUTPUT,
					@ErrMsg = @ErrMsg OUTPUT
			
				IF (@ErrCode <> 0)
				BEGIN
					SELECT @mess = @ErrMsg, @ErrCode = 1
					RETURN
				END
			END 
			SET @i=@i+1
		END	
		IF (@ERROR<>0)
		BEGIN	
			SELECT 	@ErrMsg='Please check data again: '+@mess,@ErrCode=1
		END
		ELSE
		BEGIN
			SELECT @ErrMsg='Process is SUCCESSFUL ',@ErrCode=0
		END
END



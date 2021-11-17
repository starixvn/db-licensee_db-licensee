/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/ 

USE bodb_Licensee
GO

ALTER PROCEDURE [dbo].[Acc_BA_SpecialCustUpd]
(
	@LicenseeID  INT ,
	@CustID INT ,
	@SystemID   varchar(50)='',
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
		- 20131113@winnie: Change link to DBTXN.CustDB
		- 20150606@Kathy: Change link server DBTXN.CustDB to DBCust.CustDB [Redmine:#36216]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]

	Param's Explanation:
	
*/
BEGIN
	DECLARE @ugroup_old VARCHAR(3),@isBA BIT

	-- Get old ugroup of Customer from LicenseeSpecialCust table
	SELECT @ugroup_old=ugroup 
	FROM LicenseeSpecialCust WITH (NOLOCK) 
	WHERE LicenseeID=@LicenseeID AND CustID=@CustID 
	
	IF (@ugroup_old=@ugroup) -- Nothing to do
	BEGIN
		SELECT @ErrMsg=N'Process  is successful !',@ErrCode=0
	END
	ELSE	
	BEGIN
		-- Update ugroup to LicenseeSpecialCust table
		
		UPDATE LicenseeSpecialCust WITH (ROWLOCK,UPDLOCK)
		SET ugroup=@ugroup ,modifyby=@modifyby , modifydate=getdate()
		WHERE Licenseeid=@LicenseeID AND Custid=@CustID
		
		-- Update sucessfully
		IF EXISTS(SELECT 1 FROM LicenseeSpecialCust  WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND CustID=@CustID AND ugroup=@ugroup  )
		BEGIN
			-- Is BA member
			IF EXISTS (SELECT 1 FROM LicenseeBAHistory WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND CustID=@CustID AND Status='Running')
			BEGIN
				SELECT @isBA=1 
				SELECT @ErrMsg='',@ErrCode=0

				-- Update ugroup to LicenseeBAHistory table
				UPDATE LicenseeBAHistory WITH (ROWLOCK,UPDLOCK)
				SET Ugroup = @ugroup 
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

			END
			ELSE -- Normal member
			BEGIN
				-- Update ugroup to Customer table
				EXEC CustDB.dbo.Acc_BA_SpecialCustUpdUgroup
				@custid = @CustID,
				@ugroup = @ugroup,
				@userid = @modifyby,
				@IP = @IP,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT
				
				SELECT @ErrMsg=N'Process  is successful !',@ErrCode=0
			END
			-- Write log
			EXEC Lrf_WriteLog_UserLog_LicenseeSpecialCust_Wrapper
				@LicenseeID = @LicenseeID,
				@CustID = @CustID,
				@ugroup = @ugroup,
				@ugroup_old = @ugroup_old,
				@UserId = @modifyby, 
				@IP = @IP,
				@ActionType = 'Update'
		END
		ELSE 
		BEGIN
			SELECT @ErrMsg='Update fail:'+SPACE(1)+CONVERT(VARCHAR(100),@CustID)+SPACE(1)+' Please check data again!',@ErrCode=1
			RETURN
		END
	END
END
GO


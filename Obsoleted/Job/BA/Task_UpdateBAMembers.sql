 ALTER PROCEDURE [dbo].[Task_UpdateBAMembers]
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS
/*
Created: 20120313@Minzy
Task : Update status or commision of BA Members when information of licensees change
DB: DB052.bodb_Licensee
Revisions:

Param's Explanation:

*/
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @i INT, @Max INT, @BACustID INT
	DECLARE @LicenseeID	INT, @ModifyBy INT, @IsBA bit,@IP varchar(40)
	
	SET @ErrCode=0
	SET @ErrMsg= ''
	
	SELECT @i =  MIN(id) FROM LicenseeUserToUpdate WITH (NOLOCK)
	SELECT @MAX =  MAX(id) FROM LicenseeUserToUpdate WITH (NOLOCK)
	
	WHILE @i <= @MAX
	BEGIN
		
		SELECT @BACustID = CustID,
				@LicenseeID = LicenseeID,
				@ModifyBy = ModifyBy,
				@IsBA = IsBA,
				@IP = IP
		FROM LicenseeUserToUpdate WITH (NOLOCK)
		WHERE id = @i
	
		--Check exist in Licensees
		IF NOT EXISTS (SELECT 1 FROM Licensees WITH (nolock) WHERE LicenseeID = @LicenseeID)
		BEGIN
			SELECT @ErrCode = 101, @ErrMsg = 'Invalid Licensee, please check again!'
			RETURN
		END
		--Check NOT exist in LicenseeBAConfig
		IF NOT EXISTS (SELECT 1 FROM LicenseeBAConfig WITH (nolock) WHERE LicenseeID = @LicenseeID)
		BEGIN
			SELECT @ErrCode = 102, @ErrMsg = 'This licensee does NOT have any settings!'
			RETURN
		END
		
		IF @IsBA = 0
		BEGIN
			EXEC DBTRANS.bodb02.dbo.Lrf_CustomerUpdMemberBAStatus
				@LicenseeID = @LicenseeID,
				@CustID = @BACustID,
				@ModifyBy = @ModifyBy,
				@IsBA = 0,
				@IP = @IP,
				@IsAdmin = 1,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT
		END
		ELSE
		BEGIN
			--Update commission for BA Member
			EXEC DBTRANS.bodb02.dbo.[Lrf_CustomerUpdMemberBAComm]
				@LicenseeID = @LicenseeID,
				@CustID = @BACustID,
				@ModifyBy = @ModifyBy,
				@IsBA = 1,
				@IP = @IP,
				@IsAdmin = 1,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT
		END

		IF @ErrCode <> 0
		BEGIN
			RETURN
		END
		
		DELETE FROM LicenseeUserToUpdate  WITH (ROWLOCK, UPDLOCK)
			WHERE ID = @i
		SET @i = @i + 1
	END	
END
GO

GRANT VIEW DEFINITION ON [dbo].[Task_UpdateBAMembers] TO [VNTeam]
GO   
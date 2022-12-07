/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE Lrf_MessageIns
	@MessageType	TINYINT
	,@LicenseeNames	VARCHAR(MAX)
	,@SubjectEn		NVARCHAR(300)	= NULL
	,@SubjectCs		NVARCHAR(300)	= NULL
	,@ContentEn		NVARCHAR(MAX)	= NULL
	,@ContentCs		NVARCHAR(MAX)	= NULL
	,@EventDate		DATETIME
AS
/*	
	Created by: Kai
	Task : Insert notification (#174308)
	DB: DBCUST/SiteConfig 
	Revisions:
		- 20221207@Kai: Initial sp [RedmineID: #174308]

	Param's Explanation:
		@MessageType: 1 - Abnormal Bet
		@LicenseeNames: "12Bet,Athena00,..."
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MessageID INT
	DECLARE @tblLicenseeName TABLE (LicenseeName VARCHAR(50))

	INSERT INTO @tblLicenseeName(LicenseeName)
	SELECT value 
	FROM STRING_SPLIT(@LicenseeNames, ',')
	WHERE value <> ''

	IF EXISTS (
		SELECT 1
		FROM [Message] m WITH(NOLOCK)
		WHERE m.EventDate = @EventDate
			AND m.MessageType = @MessageType
	)
	BEGIN
		SELECT @MessageID = m.MessageID
		FROM [Message] m WITH(NOLOCK)
		WHERE m.EventDate = @EventDate
			AND m.MessageType = @MessageType

		INSERT INTO [MessageLicensee] (MessageID, LicenseeName)
		SELECT @MessageID, tbl.LicenseeName
		FROM @tblLicenseeName tbl
			LEFT JOIN [MessageLicensee] ml WITH(NOLOCK)
				ON tbl.LicenseeName = ml.LicenseeName
		WHERE ml.MessageID = @MessageID
			AND ml.LicenseeName IS NULL
	END
	ELSE
	BEGIN
		INSERT INTO [Message] (
			MessageType
			,SubjectEn
			,SubjectCs
			,ContentEn
			,ContentCs
			,EventDate
			,CreatedDate
		)
		VALUES (
			@MessageType
			,@SubjectEn
			,@SubjectCs
			,@ContentEn
			,@ContentCs
			,@EventDate
			,CURRENT_TIMESTAMP
		)
	
		SET @MessageID = SCOPE_IDENTITY()
	
		INSERT INTO [MessageLicensee] (MessageID, LicenseeName)
		SELECT @MessageID, LicenseeName
		FROM @tblLicenseeName
	END
END
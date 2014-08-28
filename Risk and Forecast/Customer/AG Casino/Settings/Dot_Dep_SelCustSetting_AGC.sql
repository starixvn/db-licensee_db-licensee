ALTER PROCEDURE	dbo.Dot_Dep_SelCustSetting_AGC
	@CustID		INT,
	@AGGroup	VARCHAR(20)		OUTPUT,
	@IsEnabled	BIT				OUTPUT
AS
/*
	Created: 20140813@Victor
	Task: Get AG Casino product setting of member
	DB: DBTXN/CustDB
	Original:
	Revisions:
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @Srecommend INT
			,@SEnabled INT = 0
	SELECT @Srecommend = srecommend FROM dbo.Customer c WITH (NOLOCK) WHERE c.CustID = @CustID

	SELECT @AGGroup = '', @IsEnabled = 0
	SELECT @AGGroup = ISNULL(AGGroup,''), 
		@IsEnabled = ISNULL(IsEnabled,0)
	FROM dbo.Dep_CustSetting_AGCasino WITH (NOLOCK)
	WHERE CustID = @CustId

	SELECT @SEnabled = ISNULL(IsEnabled,0) FROM dbo.Dep_SuperSetting_AGCasino WITH (NOLOCK) WHERE CustID = @Srecommend

	IF (@SEnabled = 0)
		SELECT @IsEnabled = 0
END

GO

GRANT EXECUTE ON dbo.[Dot_Dep_SelCustSetting_AGC] TO [Dot_Member]
GO
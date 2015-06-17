USE [CustDB]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_3rdProductSelCustStatus]    Script Date: 06/06/2015 14:22:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE	[dbo].[Lrf_3rdProductSelCustStatus]
	@CustID			INT,
	@ProductId		INT,
	@IsEnabled		BIT=NULL				OUTPUT,
	@IsLineEnabled	BIT=NULL		 		OUTPUT,
	@Currency		INT=NULL				OUTPUT
AS
/*
	Created: 20150304@Winnie
	Task: Get 3rd product status of member
	DB: DBCust.CustDB
	
	Original:
	Revisions:
		- 20150603@Kathy: Move SP to DBCust.custDB [Redmine:#36216]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @Srecommend INT

	SELECT @Srecommend = srecommend ,@Currency=c.currency
	FROM dbo.Customer c WITH (NOLOCK) 
	WHERE c.CustID = @CustID
	
	SELECT @IsEnabled = ISNULL(IsEnabled,0)
	FROM dbo.Dep_CustProductSetting WITH (NOLOCK)
	WHERE CustID = @CustId AND ProductId=@ProductId
	
	SELECT @IsLineEnabled = ISNULL(IsEnabled, 0) 		
	FROM dbo.Dep_SupperProductSetting WITH (NOLOCK) 
	WHERE CustID = @Srecommend  AND ProductId=@ProductId

	IF (@IsLineEnabled = 0)
		SELECT @IsEnabled = 0
	
END


GO
GRANT EXECUTE ON [dbo].[Lrf_3rdProductSelCustStatus] TO [bodbLicenseeNet] AS [dbo]
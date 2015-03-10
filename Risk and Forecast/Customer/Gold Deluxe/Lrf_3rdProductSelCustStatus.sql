USE [bodb_licensee]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_3rdProductSelCustStatus]    Script Date: 3/9/2015 12:45:58 PM ******/
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
	DB: DBLIC/bodb_licensee
	Original:
	Revisions:
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @Srecommend INT

	SELECT @Srecommend = srecommend ,@Currency=c.currency
	FROM bodb02.dbo.Customer c WITH (NOLOCK) 
	WHERE c.CustID = @CustID
	
	SELECT @IsEnabled = ISNULL(IsEnabled,0)
	FROM DBTXN.CustDB.dbo.Dep_CustProductSetting WITH (NOLOCK)
	WHERE CustID = @CustId AND ProductId=@ProductId
	
	SELECT @IsLineEnabled = ISNULL(IsEnabled, 0) 		
	FROM DBTXN.CustDB.dbo.Dep_SupperProductSetting WITH (NOLOCK) 
	WHERE CustID = @Srecommend  AND ProductId=@ProductId

	IF (@IsLineEnabled = 0)
		SELECT @IsEnabled = 0
	
END


SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Lrf_3rdProductSelCustStatus    Script Date: 6/10/2015 10:51:17 AM ******/
CREATE PROCEDURE	[dbo].[Lrf_3rdProductSelCustStatus]
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
		- 20150609@Jim: support product microgaming
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
	
	IF (@ProductId = 14) ---Microgaming 
		BEGIN
			SELECT @IsEnabled = CASE DisableMicrogame WHEN 0 THEN 1 ELSE 0 END 
			FROM bodb02.dbo.CustInfo WITH (NOLOCK) 
			WHERE CustID = @CustID
			IF @IsEnabled = 1
				SET @IsLineEnabled =1
			ELSE 
				SELECT @IsLineEnabled = CASE DisableMicrogame WHEN 0 THEN 1 ELSE 0 END 
				FROM bodb02.dbo.CustInfo WITH (NOLOCK) 
				WHERE CustID = @Srecommend
		END
	IF (@IsLineEnabled = 0)
		SELECT @IsEnabled = 0
	
END

GRANT EXECUTE ON [dbo].[Lrf_3rdProductSelCustStatus] TO [bodbLicenseeNet]

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Lrf_3rdProductSelCustStatus] TO [bodbLicenseeNet]
GO 

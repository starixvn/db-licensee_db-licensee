 
CREATE  PROCEDURE	[dbo].[Lrf_3rdProductSelCustStatus]
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
		- 20150722@Jim: apply new DBCust structure
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @Srecommend INT
			,@Mrecommend INT
			,@Recommend  INT

	SELECT @Srecommend = srecommend 
			,@Mrecommend = Mrecommend
			 ,@Recommend = Recommend
			,@Currency=c.currency
	FROM bodb02.dbo.Customer c WITH (NOLOCK) 
	WHERE c.CustID = @CustID
	
	SELECT @IsEnabled = ISNULL(IsEnabled,0)
	FROM DBCUST.CustDB.dbo.Dep_CustProductSetting WITH (NOLOCK)
	WHERE CustID = @CustId AND ProductId=@ProductId
	
	SELECT @IsLineEnabled = ISNULL(IsEnabled, 0) 		
	FROM DBCUST.CustDB.dbo.Dep_SupperProductSetting WITH (NOLOCK) 
	WHERE CustID = @Srecommend  AND ProductId=@ProductId
	
	IF (@ProductId = 14) ---Microgaming 
		BEGIN
			SELECT @IsEnabled = CASE DisableMicrogame WHEN 0 THEN 1 ELSE 0 END 
			FROM bodb02.dbo.CustInfo WITH (NOLOCK) 
			WHERE CustID = @CustID
			IF EXISTS( 
				SELECT 1
				FROM bodb02.dbo.CustInfo WITH (NOLOCK) 
				WHERE CustID = @Srecommend AND DisableMicrogame = 0 )
				AND EXISTS (
				SELECT 1
				FROM bodb02.dbo.CustInfo WITH (NOLOCK) 
				WHERE CustID = @Mrecommend AND DisableMicrogame = 0 )
				AND EXISTS (
				SELECT 1
				FROM bodb02.dbo.CustInfo WITH (NOLOCK) 
				WHERE CustID = @Recommend AND DisableMicrogame = 0)
 
				SET @IsLineEnabled = 1 
			ELSE 	
				SET @IsLineEnabled = 0
		END	
	IF (@IsLineEnabled = 0)
		SELECT @IsEnabled = 0
	
END

GRANT EXECUTE ON [dbo].[Lrf_3rdProductSelCustStatus] TO [bodbLicenseeNet]
 
GO 
 GRANT EXECUTE ON [dbo].[Lrf_3rdProductSelCustStatus] TO [bodbLicenseeNet]
GO 

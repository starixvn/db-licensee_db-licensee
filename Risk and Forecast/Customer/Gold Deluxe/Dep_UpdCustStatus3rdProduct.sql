ALTER PROCEDURE	dbo.Dep_3rdProductUpdCustStatus 
	@CustIDs	VARCHAR(MAX),
	@ProductId	INT,
	@IsEnabled	BIT,
	@ErrMsg		VARCHAR(100)	= ''	OUTPUT
AS
/*
	Created: 20150304@Winnie
	Task: Update status of 3rd product(Gold Dexluxe...) for Members
	DB: DBTXN.CustDB
	Original:
	Revisions:
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #CustList (CustID INT)

	INSERT INTO #CustList (CustID)
	SELECT val FROM dbo.strSplit(@CustIDs,',')
	IF(@@ERROR<>0)
	BEGIN
	SELECT @ErrMsg='Could not update'
	RETURN
	END

	UPDATE dbo.Dep_CustProductSetting WITH (ROWLOCK, UPDLOCK)
	SET IsEnabled = @IsEnabled
	WHERE ProductId=@ProductId AND CustID IN (SELECT CustID FROM #CustList)
	IF(@@ERROR<>0)
	BEGIN
	SELECT @ErrMsg='Could not update'
	RETURN
	END
	
	INSERT INTO dbo.Dep_CustProductSetting (CustID, ProductId, IsEnabled)
	SELECT CustID, @ProductId, @IsEnabled	
	FROM #CustList c
	WHERE NOT EXISTS(SELECT 1 FROM dbo.Dep_CustProductSetting cs WITH (NOLOCK) WHERE cs.CustID = c.CustID AND cs.ProductId=@ProductId)
	IF(@@ERROR<>0)
	BEGIN
	SELECT @ErrMsg='Could not insert'
	RETURN
	END
END

GO

GRANT EXECUTE ON dbo.Dep_3rdProductUpdCustStatus TO bodbLicenseeNet
GO
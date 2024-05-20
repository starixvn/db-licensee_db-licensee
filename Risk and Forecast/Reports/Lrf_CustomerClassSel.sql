/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Lrf_CustomerClassSel
	@CustomerClass SMALLINT =  0
	
AS
/*
	Created: 20201103@Winfred
	Task: Get list customer class 
	DB: DBCUST/CUSTDB
	
	Revisions:
		- 20201103@Winfred: initial sp [redmine:#144706]
	Parameter's explanations:
	+ @CustomerClass: '0' (all)	 or @CustomerClass = '1'
*/
BEGIN
	SET NOCOUNT ON;
	
	IF @CustomerClass IS NULL 
	BEGIN
	 SET @CustomerClass = 0 
	END 
	
    -- Insert statements for procedure here
    SELECT DISTINCT CustomerClass
	FROM CustomerClassPolicy c1 WITH(NOLOCK)
	WHERE c1.isLicensee = 1
		AND c1.Enabled = 1
		AND (@CustomerClass = 0 OR CustomerClass = @CustomerClass )
	UNION ALl
	SELECT DISTINCT CustomerClass
	FROM CustomerClassSitePolicy c2 WITH(NOLOCK)
	WHERE c2.isLicensee = 1
		AND c2.Enabled = 1	
		AND (@CustomerClass = 0 OR c2.CustomerClass = @CustomerClass )
		AND NOT EXISTS (SELECT 1
						FROM CustomerClassPolicy c1 WITH(NOLOCK)
						WHERE c1.customerClass = c2.customerClass
							AND c1.isLicensee = c2.isLicensee
							AND c1.Enabled = c2.Enabled
						)
	ORDER BY CustomerClass 						
END
GO

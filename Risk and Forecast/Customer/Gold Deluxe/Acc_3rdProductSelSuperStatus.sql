USE [CustDB]
GO
/****** Object:  StoredProcedure [dbo].[Acc_3rdProductSelSuperStatus]    Script Date: 3/16/2015 4:51:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON 
GO
ALTER PROCEDURE	[dbo].[Acc_3rdProductSelSuperStatus]
	@ProductID			INT,
	@CustID				INT,
	@SupperStatus		BIT=0 OUTPUT,
	@DownlineStatus		BIT=0 OUTPUT
AS
/*
	Created: 20150313@Winne
	Task: select 3rd product status of super ( 12 GoldDeluxe)
	DB: DBTXN/CustDB
	Original:
	Revisions:
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT @SupperStatus=IsEnabled FROM Dep_SupperProductSetting  WITH (NOLOCK) WHERE CustID = @CustID AND ProductId=@ProductId	

	CREATE TABLE #CustList ( CustID INT)		
		INSERT INTO #CustList (CustID)
		SELECT rm.CustID FROM Customer rm WITH (NOLOCK) 
		INNER JOIN Customer ag WITH (NOLOCK) ON rm.recommend=ag.Custid
		WHERE rm.srecommend = @CustID AND rm.roleid = 1 AND ag.Username not like '%'+ag.site +'ACC%'

	IF EXISTS(SELECT TOP 1 1 FROM Dep_CustProductSetting a WITH (NOLOCK) INNER JOIN #CustList b ON a.CustID=b.CustID 
				WHERE a.ProductId=@ProductId  AND a.IsEnabled=1)
	
	SELECT @DownlineStatus=1
	ELSE
	SELECT @DownlineStatus=0

	
END


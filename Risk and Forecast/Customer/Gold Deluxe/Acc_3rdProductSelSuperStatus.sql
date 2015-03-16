USE [CustDB]
GO 
/****** Object:  StoredProcedure [dbo].[Acc_AGC_UpdSuperStatus]    Script Date: 3/9/2015 2:26:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE	[dbo].[Acc_3rdProductSelSuperStatus]
	@ProductID			INT,
	@CustID				INT,
	@SupperStatus		INT,
	@DownlineStatus		INT
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
	
	SELECT @SupperStatus=Status FROM Dep_SupperProductSetting  WITH (NOLOCK) WHERE CustID = @CustID AND ProductId=@ProductId	
	
END

GO
GRANT EXECUTE ON dbo.[Acc_3rdProductSelSuperStatus] TO bodbAdminNet
GO


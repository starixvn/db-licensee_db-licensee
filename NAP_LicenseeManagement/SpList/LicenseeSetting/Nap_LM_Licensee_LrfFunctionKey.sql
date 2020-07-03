/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_Licensee_LrfFunctionKey]
	@ProductCode VARCHAR(100) = ''
AS
/*
	 Created: Amanda
	 Date: 2018-11-13
	 Task: Implement "Licensee Setting" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20181113@Amanda: Get lrf function keys by product code [Redmine: #83584]
	  - 20190425@Amanda: Add BA function [Redmine: #111321]
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @tblProductPrefix AS TABLE(ID INT IDENTITY(1,1), ProductCode VARCHAR(100))
	DECLARE @tblFunctions AS TABLE (ProductId INT,FunctionId INT,TypeID INT)
	DECLARE @n INT, @m INT, @ProductName VARCHAR(5)
	
	INSERT INTO @tblProductPrefix (ProductCode)  
	SELECT val 
	FROM CUSTDB.dbo.strSplit(@ProductCode,',')
	
	SELECT @n = 1  
		,@m = MAX(ID) FROM @tblProductPrefix  
	WHILE (@n <= @m)     
	BEGIN  
		SELECT @ProductName = ProductCode FROM @tblProductPrefix WHERE ID = @n  
    
		INSERT INTO @tblFunctions  
		EXEC Nap_LM_Function_GetByProduct @ProductCode = @ProductName  
      
		SET @n = @n +1   
	END 
	
	SELECT af.FunctionKey
	FROM dbo.Functions af WITH (NOLOCK)
	INNER JOIN @tblFunctions f ON af.FunctionId = f.FunctionId
	WHERE f.TypeID = 1 AND f.TypeID = 3 -- LRF
END
GO
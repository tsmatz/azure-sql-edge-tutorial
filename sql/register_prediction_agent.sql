USE [FoodInspection];
GO

CREATE PROCEDURE assign_item_grade
AS
    -- Load onnx model
    DECLARE @model VARBINARY(MAX) = (SELECT [data] FROM [FoodInspection].[dbo].[Models] WHERE [id] = 1);

    -- Create temp table
    CREATE TABLE #TempNewResults
    (
        [timestamp] [DATETIME2](7) NULL,
        [weight] REAL NULL,
        [concentration] REAL NULL,
        [grade] INT NULL
    );

    -- Insert data (in which grade is not assigned) into temp table
    INSERT INTO [#TempNewResults] ([timestamp], [weight], [concentration])
    SELECT [timestamp], CAST([weight] AS REAL), CAST([concentration] AS REAL) FROM [FoodInspection].[dbo].[InspectionResults]
    WHERE [grade] IS NULL;

    -- Set grade in temp table
    MERGE [#TempNewResults] AS OrgTable
    USING (
        SELECT [#TempNewResults].[timestamp] AS [timestamp], p.output_label1 as [grade] FROM PREDICT(MODEL = @model, DATA = [#TempNewResults], Runtime=ONNX) WITH (output_label1 REAL) AS p
    ) AS PredTable
    ON [OrgTable].[timestamp] = [PredTable].[timestamp]
    WHEN MATCHED THEN
    UPDATE SET [OrgTable].[grade] = [PredTable].[grade];

    -- Merge grade with InspectionResults table
    MERGE [FoodInspection].[dbo].[InspectionResults] AS OrgTable
    USING (SELECT [timestamp], [grade] FROM [#TempNewResults]) AS TempTable
    ON [OrgTable].[timestamp] = [TempTable].[timestamp]
    WHEN MATCHED THEN
    UPDATE SET [OrgTable].[grade] = [TempTable].[grade];

    -- Insert into DefectiveItems table
    INSERT INTO [FoodInspection].[dbo].[DefectiveItems] ([timestamp], [weight], [concentration])
    SELECT [timestamp], CAST([weight] AS NUMERIC(25, 20)), CAST([concentration] AS NUMERIC(25, 20))
    FROM [#TempNewResults]
    WHERE [grade] = -1

    -- Drop temp table
    DROP TABLE [#TempNewResults];
GO

-- Create and register SQL agent job

USE [msdb];
GO

EXEC dbo.sp_add_job  
    @job_name = N'AssignGradeJob' ;  
GO

EXEC dbo.sp_add_jobstep
    @job_name = N'AssignGradeJob',
    @step_name = N'SetGradeAndDetectDefective',
    @subsystem = N'TSQL',
    @command = N'EXEC FoodInspection.dbo.assign_item_grade',
    @retry_attempts = 5,
    @retry_interval = 5;
GO

EXEC dbo.sp_add_schedule  
    @schedule_name = N'Every2Minutes',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 2;

EXEC dbo.sp_attach_schedule  
   @job_name = N'AssignGradeJob',  
   @schedule_name = N'Every2Minutes';
GO

EXEC dbo.sp_add_jobserver  
    @job_name = N'AssignGradeJob';  
GO

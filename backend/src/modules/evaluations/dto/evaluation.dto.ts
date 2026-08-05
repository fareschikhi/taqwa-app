import { IsInt, IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';

export class CreateEvaluationDto {
  @IsInt() studentId: number;
  @IsInt() teacherId: number;
  
  @IsOptional() @IsNumber() @Min(0) @Max(100) memorizationScore?: number;
  @IsOptional() @IsNumber() @Min(0) @Max(100) tajweedScore?: number;
  @IsOptional() @IsNumber() @Min(0) @Max(100) fluencyScore?: number;
  @IsOptional() @IsNumber() @Min(0) @Max(100) disciplineScore?: number;
  @IsOptional() @IsNumber() @Min(0) @Max(100) overallScore?: number;
  @IsOptional() @IsString() notes?: string;
}

export class UpdateEvaluationDto {
  @IsOptional() @IsNumber() @Min(0) @Max(100) memorizationScore?: number;
  @IsOptional() @IsNumber() @Min(0) @Max(100) tajweedScore?: number;
  @IsOptional() @IsNumber() @Min(0) @Max(100) fluencyScore?: number;
  @IsOptional() @IsNumber() @Min(0) @Max(100) disciplineScore?: number;
  @IsOptional() @IsNumber() @Min(0) @Max(100) overallScore?: number;
  @IsOptional() @IsString() notes?: string;
}
